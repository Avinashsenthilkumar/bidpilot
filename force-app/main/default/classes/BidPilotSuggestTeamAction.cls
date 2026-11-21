public with sharing class BidPilotSuggestTeamAction {

    public class Request {
        @InvocableVariable(label='Bid Reference' description='Bid number (e.g. BID-0001) or Bid record Id' required=true)
        public String bidReference;
    }

    public class Response {
        @InvocableVariable(label='Team Summary' description='Suggested team, one member per line')
        public String teamSummary;
        @InvocableVariable(label='Skill Gaps' description='Skills with no available resource')
        public String skillGaps;
        @InvocableVariable(label='Message' description='Result of the action')
        public String message;
    }

    @InvocableMethod(
        label='BidPilot: Suggest Team'
        description='Matches available resources to each skill needed by the bid based on skills and current allocation, and recalculates cost and duration. Call after effort is estimated.'
        category='BidPilot')
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            Response res = new Response();
            Savepoint sp = Database.setSavepoint();
            try {
                res = suggest(BidPilotService.resolveBidId(r.bidReference));
            } catch (Exception e) {
                Database.rollback(sp);
                res.message = 'Could not build the team: ' + e.getMessage();
            }
            out.add(res);
        }
        return out;
    }

    private static Response suggest(Id bidId) {
        Bid__c b = BidPilotService.getBid(bidId);
        if (b.Modules__r.isEmpty() || b.Total_Effort_Hours__c == null) {
            throw new BidPilotService.BidPilotException('Estimate the effort first.');
        }

        // Hours needed per skill (dev hours)
        Map<String, Decimal> hoursBySkill = new Map<String, Decimal>();
        Map<String, String> labelBySkill = new Map<String, String>();
        Decimal devHours = 0;
        for (Bid_Module__c m : b.Modules__r) {
            String key = (String.isBlank(m.Skill__c) ? 'General' : m.Skill__c).trim().toLowerCase();
            Decimal h = BidPilotService.nz(m.Effort_Hours__c);
            hoursBySkill.put(key, BidPilotService.nz(hoursBySkill.get(key)) + h);
            labelBySkill.put(key, String.isBlank(m.Skill__c) ? 'General' : m.Skill__c.trim());
            devHours += h;
        }

        List<Resource__c> pool = [
            SELECT Id, Name, Role__c, Skills__c, Hourly_Rate__c, Current_Allocation__c, Experience_Years__c
            FROM Resource__c
            WHERE Active__c = true
            ORDER BY Current_Allocation__c ASC NULLS FIRST, Experience_Years__c DESC NULLS LAST
        ];

        Set<Id> used = new Set<Id>();
        List<Bid_Team_Member__c> team = new List<Bid_Team_Member__c>();
        Map<Id, Resource__c> byId = new Map<Id, Resource__c>(pool);
        List<String> gaps = new List<String>();

        for (String key : hoursBySkill.keySet()) {
            Resource__c pick = pickResource(pool, labelBySkill.get(key), used);
            Bid_Team_Member__c tm = new Bid_Team_Member__c(
                Bid__c = b.Id,
                Skill__c = labelBySkill.get(key),
                Planned_Hours__c = hoursBySkill.get(key)
            );
            if (pick != null) {
                used.add(pick.Id);
                tm.Resource__c = pick.Id;
                tm.Role__c = pick.Role__c;
                tm.Allocation__c = 100 - BidPilotService.nz(pick.Current_Allocation__c);
            } else {
                tm.Role__c = 'Open position';
                tm.Allocation__c = 100;
                gaps.add(labelBySkill.get(key));
            }
            team.add(tm);
        }

        // Project manager covers the QA/PM overhead hours
        Decimal overhead = b.Total_Effort_Hours__c - devHours;
        if (overhead > 0) {
            Resource__c pm = null;
            for (Resource__c rr : pool) {
                if (!used.contains(rr.Id) && rr.Role__c != null && rr.Role__c.containsIgnoreCase('manager')
                        && (rr.Current_Allocation__c == null || rr.Current_Allocation__c < 100)) {
                    pm = rr; break;
                }
            }
            team.add(new Bid_Team_Member__c(
                Bid__c = b.Id,
                Resource__c = pm == null ? null : pm.Id,
                Role__c = pm == null ? 'Project Manager (open)' : pm.Role__c,
                Skill__c = 'Project Management',
                Allocation__c = pm == null ? 50.0 : Math.min(50.0, 100 - BidPilotService.nz(pm.Current_Allocation__c)),
                Planned_Hours__c = overhead.setScale(1)
            ));
        }

        delete [SELECT Id FROM Bid_Team_Member__c WHERE Bid__c = :b.Id];
        insert team;

        // Cost and duration from the real team
        Decimal cost = 0, weeks = 0;
        List<String> lines = new List<String>();
        for (Bid_Team_Member__c tm : team) {
            Resource__c rr = tm.Resource__c == null ? null : byId.get(tm.Resource__c);
            Decimal rate = (rr != null && rr.Hourly_Rate__c != null) ? rr.Hourly_Rate__c : BidPilotService.DEFAULT_RATE;
            cost += tm.Planned_Hours__c * rate;
            Decimal alloc = (tm.Allocation__c == null || tm.Allocation__c <= 0) ? 100.0 : tm.Allocation__c;
            Decimal w = tm.Planned_Hours__c / (BidPilotService.HOURS_PER_WEEK * alloc / 100);
            if (tm.Skill__c != 'Project Management' && w > weeks) weeks = w;
            lines.add((rr == null ? 'OPEN' : rr.Name) + ' - ' + tm.Role__c + ' | ' + tm.Skill__c + ' | '
                + tm.Allocation__c.setScale(0) + '% | ' + tm.Planned_Hours__c.setScale(0) + 'h');
        }
        weeks = weeks.setScale(1, System.RoundingMode.CEILING);

        update new Bid__c(Id = b.Id, Status__c = 'Team Assigned',
            Estimated_Cost__c = cost.setScale(0), Duration_Weeks__c = weeks);

        Response res = new Response();
        res.teamSummary = String.join(lines, '\n');
        res.skillGaps = gaps.isEmpty() ? 'None' : String.join(gaps, ', ');
        res.message = 'Team of ' + team.size() + ' suggested. Duration ' + weeks + ' weeks, cost '
            + BidPilotService.inr(cost) + '. Skill gaps: ' + res.skillGaps + '.';
        return res;
    }

    // A person must have at least this much free capacity to be staffed; otherwise the skill
    // becomes an open position (hire / contractor) instead of stretching the timeline.
    @TestVisible static final Decimal MIN_FREE_CAPACITY = 40;

    private static Resource__c pickResource(List<Resource__c> pool, String skill, Set<Id> used) {
        for (Resource__c rr : pool) {
            Decimal free = 100 - BidPilotService.nz(rr.Current_Allocation__c);
            if (free >= MIN_FREE_CAPACITY && !used.contains(rr.Id) && BidPilotService.skillMatches(skill, rr.Skills__c)) {
                return rr;
            }
        }
        return null;
    }
}
