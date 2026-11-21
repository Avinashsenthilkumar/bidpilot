/**
 * BidPilot shared logic used by all Agentforce actions.
 * Estimation, team matching, risk scoring and proposal text live here
 * so the agent actions stay thin and the logic is unit-testable.
 */
public with sharing class BidPilotService {

    public static final Map<String, Decimal> BASE_HOURS = new Map<String, Decimal>{
        'Low' => 40, 'Medium' => 100, 'High' => 200
    };
    public static final Decimal OVERHEAD_FACTOR = 1.25;   // +15% QA, +10% PM
    public static final Decimal HOURS_PER_WEEK = 40;
    public static final Decimal DEFAULT_RATE = 1500;      // INR/hour when no resource rate
    public static final Integer HIGH_RISK_THRESHOLD = 60;
    public static final Integer MEDIUM_RISK_THRESHOLD = 35;

    public class BidPilotException extends Exception {}

    // ---------------------------------------------------------------- lookup
    /** Accepts a record Id or a bid number such as BID-0001. */
    public static Id resolveBidId(String ref) {
        if (String.isBlank(ref)) {
            throw new BidPilotException('Please provide a Bid number (e.g. BID-0001).');
        }
        String r = ref.trim();
        if (r.length() == 15 || r.length() == 18) {
            try {
                Id candidate = Id.valueOf(r);
                if (candidate.getSObjectType() == Bid__c.SObjectType) {
                    return candidate;
                }
            } catch (Exception e) {
                // not an Id, fall through to name lookup
            }
        }
        List<Bid__c> bids = [SELECT Id FROM Bid__c WHERE Name = :r.toUpperCase() LIMIT 1];
        if (bids.isEmpty()) {
            throw new BidPilotException('No Bid found for "' + r + '".');
        }
        return bids[0].Id;
    }

    public static Bid__c getBid(Id bidId) {
        return [
            SELECT Id, Name, OwnerId, Client_Name__c, Project_Title__c, SOW_Content__c,
                   Requested_Timeline_Weeks__c, Status__c, Tech_Stack__c, Total_Effort_Hours__c,
                   Estimated_Cost__c, Duration_Weeks__c, Risk_Score__c, Risk_Level__c,
                   Risk_Factors__c, Risk_Breakdown__c, Calibration_Factor__c, Similar_Projects__c,
                   Proposal_Summary__c, Client_Email_Draft__c, Approval_Comments__c, Opportunity__c,
                   (SELECT Id, Name, Complexity__c, Skill__c, Description__c, Effort_Hours__c
                      FROM Modules__r ORDER BY CreatedDate, Name),
                   (SELECT Id, Name, Resource__c, Resource__r.Name, Resource__r.Hourly_Rate__c,
                           Role__c, Skill__c, Allocation__c, Planned_Hours__c
                      FROM Team_Members__r ORDER BY Skill__c)
            FROM Bid__c WHERE Id = :bidId
        ];
    }

    // ---------------------------------------------------------- helpers
    public static String normalizeComplexity(String c) {
        if (String.isBlank(c)) return 'Medium';
        String v = c.trim().toLowerCase();
        if (v.startsWith('h') || v.contains('complex')) return 'High';
        if (v.startsWith('l') || v.contains('simple') || v.contains('easy')) return 'Low';
        return 'Medium';
    }

    public static Set<String> splitSkills(String raw) {
        Set<String> out = new Set<String>();
        if (String.isBlank(raw)) return out;
        for (String s : raw.split('[,;/|]')) {
            if (String.isNotBlank(s)) out.add(s.trim().toLowerCase());
        }
        return out;
    }

    public static Boolean skillMatches(String required, String resourceSkills) {
        if (String.isBlank(required)) return false;
        String req = required.trim().toLowerCase();
        for (String s : splitSkills(resourceSkills)) {
            if (s == req || s.contains(req) || req.contains(s)) return true;
        }
        return false;
    }

    public static Integer countLines(String text) {
        if (String.isBlank(text)) return 0;
        Integer n = 0;
        for (String l : text.split('[\\n;]')) {
            if (String.isNotBlank(l)) n++;
        }
        return n;
    }

    /** Null-safe decimal. */
    public static Decimal nz(Decimal d) {
        return d == null ? 0.0 : d;
    }

    public static String inr(Decimal amount) {
        if (amount == null) return 'INR 0';
        return 'INR ' + amount.setScale(0).format();
    }

    // ------------------------------------------------------- estimation
    public class EstimateResult {
        public Decimal totalHours;
        public Decimal calibration;
        public List<String> similar = new List<String>();
    }

    public static EstimateResult estimate(Bid__c bid) {
        if (bid.Modules__r == null || bid.Modules__r.isEmpty()) {
            throw new BidPilotException('No modules found. Run SOW analysis first.');
        }
        Set<String> bidSkills = new Set<String>();
        for (Bid_Module__c m : bid.Modules__r) bidSkills.addAll(splitSkills(m.Skill__c));
        bidSkills.addAll(splitSkills(bid.Tech_Stack__c));

        // Calibrate from delivered projects that share skills
        Decimal planned = 0, actual = 0;
        List<ProjectScore> scored = new List<ProjectScore>();
        for (Past_Project__c p : [
                SELECT Name, Client_Name__c, Skills__c, Planned_Effort_Hours__c, Actual_Effort_Hours__c
                FROM Past_Project__c
                WHERE Planned_Effort_Hours__c > 0 AND Actual_Effort_Hours__c > 0
                LIMIT 500]) {
            Integer overlap = 0;
            for (String s : splitSkills(p.Skills__c)) {
                for (String b : bidSkills) {
                    if (s == b || s.contains(b) || b.contains(s)) { overlap++; break; }
                }
            }
            if (overlap > 0) {
                planned += p.Planned_Effort_Hours__c;
                actual += p.Actual_Effort_Hours__c;
                scored.add(new ProjectScore(p, overlap));
            }
        }
        scored.sort();

        EstimateResult res = new EstimateResult();
        res.calibration = planned > 0 ? (actual / planned).setScale(2) : 1.00;
        for (Integer i = 0; i < Math.min(3, scored.size()); i++) {
            Past_Project__c p = scored[i].project;
            Decimal var = ((p.Actual_Effort_Hours__c / p.Planned_Effort_Hours__c - 1) * 100).setScale(0);
            res.similar.add(p.Name + ' (' + p.Client_Name__c + ') - planned ' + p.Planned_Effort_Hours__c.setScale(0)
                + 'h, actual ' + p.Actual_Effort_Hours__c.setScale(0) + 'h (' + (var >= 0 ? '+' : '') + var + '%)');
        }

        Decimal dev = 0;
        for (Bid_Module__c m : bid.Modules__r) {
            Decimal h = (BASE_HOURS.get(normalizeComplexity(m.Complexity__c)) * res.calibration).setScale(1);
            m.Effort_Hours__c = h;
            dev += h;
        }
        res.totalHours = (dev * OVERHEAD_FACTOR).setScale(1);
        return res;
    }

    public class ProjectScore implements Comparable {
        public Past_Project__c project;
        public Integer score;
        public ProjectScore(Past_Project__c p, Integer s) { project = p; score = s; }
        public Integer compareTo(Object o) {
            ProjectScore other = (ProjectScore) o;
            return other.score - score; // descending
        }
    }

    // ------------------------------------------------------------- risk
    public class RiskResult {
        public Integer score = 0;
        public String level;
        public List<String> reasons = new List<String>();
    }

    public static RiskResult assessRisk(Bid__c bid) {
        RiskResult r = new RiskResult();

        // 1. Timeline pressure
        if (bid.Requested_Timeline_Weeks__c != null && bid.Requested_Timeline_Weeks__c > 0
                && bid.Duration_Weeks__c != null && bid.Duration_Weeks__c > bid.Requested_Timeline_Weeks__c) {
            Integer over = (((bid.Duration_Weeks__c / bid.Requested_Timeline_Weeks__c) - 1) * 100).intValue();
            Integer pts = Math.min(40, Math.max(10, over));
            r.score += pts;
            r.reasons.add('Timeline: needs ' + bid.Duration_Weeks__c + ' weeks vs ' + bid.Requested_Timeline_Weeks__c + ' requested (+' + pts + ')');
        }

        // 2. Complexity
        Integer high = 0;
        Set<String> skills = new Set<String>();
        for (Bid_Module__c m : bid.Modules__r) {
            if (normalizeComplexity(m.Complexity__c) == 'High') high++;
            if (String.isNotBlank(m.Skill__c)) skills.add(m.Skill__c.trim().toLowerCase());
        }
        if (high > 0) {
            Integer pts = Math.min(30, high * 10);
            r.score += pts;
            r.reasons.add(high + ' high-complexity module(s) (+' + pts + ')');
        }

        // 3. Skill gaps
        Set<String> covered = new Set<String>();
        for (Bid_Team_Member__c t : bid.Team_Members__r) {
            if (t.Resource__c != null && String.isNotBlank(t.Skill__c)) covered.add(t.Skill__c.trim().toLowerCase());
        }
        Integer gaps = 0;
        for (String s : skills) if (!covered.contains(s)) gaps++;
        if (gaps > 0) {
            Integer pts = Math.min(30, gaps * 15);
            r.score += pts;
            r.reasons.add(gaps + ' skill(s) with no available resource (+' + pts + ')');
        }

        // 4. Risks called out in the SOW
        Integer flagged = countLines(bid.Risk_Factors__c);
        if (flagged > 0) {
            Integer pts = Math.min(20, flagged * 5);
            r.score += pts;
            r.reasons.add(flagged + ' risk factor(s) found in SOW (+' + pts + ')');
        }

        // 5. Historical overrun
        if (bid.Calibration_Factor__c != null && bid.Calibration_Factor__c > 1.2) {
            r.score += 10;
            r.reasons.add('Similar past projects overran by ' + ((bid.Calibration_Factor__c - 1) * 100).setScale(0) + '% (+10)');
        }

        r.score = Math.min(100, r.score);
        r.level = r.score >= HIGH_RISK_THRESHOLD ? 'High' : (r.score >= MEDIUM_RISK_THRESHOLD ? 'Medium' : 'Low');
        return r;
    }

    // --------------------------------------------------- notifications
    public static Id approverFor(Id ownerId) {
        List<User> u = [SELECT ManagerId FROM User WHERE Id = :ownerId LIMIT 1];
        return (!u.isEmpty() && u[0].ManagerId != null) ? u[0].ManagerId : ownerId;
    }

    public static void notify(Id userId, Id targetId, String title, String body) {
        try {
            List<CustomNotificationType> types = [
                SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'BidPilot_Approval' LIMIT 1
            ];
            if (types.isEmpty()) return;
            Messaging.CustomNotification n = new Messaging.CustomNotification();
            n.setNotificationTypeId(types[0].Id);
            n.setTitle(title);
            n.setBody(body);
            n.setTargetId(targetId);
            n.send(new Set<String>{ String.valueOf(userId) });
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'BidPilot notification failed: ' + e.getMessage());
        }
    }

    // ---------------------------------------------------- proposal text
    public static String buildProposal(Bid__c bid) {
        List<String> lines = new List<String>();
        lines.add('PROPOSAL: ' + bid.Project_Title__c + ' for ' + bid.Client_Name__c);
        lines.add('');
        lines.add('Scope (' + bid.Modules__r.size() + ' modules):');
        for (Bid_Module__c m : bid.Modules__r) {
            Decimal h = nz(m.Effort_Hours__c).setScale(0);
            lines.add('  - ' + m.Name + ' [' + m.Complexity__c + ', ' + m.Skill__c + '] ' + h + 'h');
        }
        lines.add('');
        lines.add('Tech stack: ' + (String.isBlank(bid.Tech_Stack__c) ? 'To be finalised' : bid.Tech_Stack__c));
        lines.add('Total effort: ' + bid.Total_Effort_Hours__c.setScale(0) + ' hours (incl. QA and project management)');
        lines.add('Duration: ' + bid.Duration_Weeks__c + ' weeks');
        lines.add('Investment: ' + inr(bid.Estimated_Cost__c));
        lines.add('');
        lines.add('Proposed team:');
        for (Bid_Team_Member__c t : bid.Team_Members__r) {
            lines.add('  - ' + (t.Resource__c != null ? t.Resource__r.Name : 'To be hired') + ' - ' + t.Role__c + ' (' + t.Skill__c + ', ' + t.Allocation__c + '%)');
        }
        lines.add('');
        lines.add('Risk: ' + bid.Risk_Level__c + ' (' + bid.Risk_Score__c + '/100)');
        if (String.isNotBlank(bid.Risk_Factors__c)) lines.add('Key risks and mitigations: ' + bid.Risk_Factors__c.replace('\n', '; '));
        return String.join(lines, '\n');
    }

    public static String buildEmail(Bid__c bid) {
        return 'Subject: Proposal - ' + bid.Project_Title__c + '\n\n'
            + 'Dear ' + bid.Client_Name__c + ' team,\n\n'
            + 'Thank you for sharing the scope of work for ' + bid.Project_Title__c + '. '
            + 'We have reviewed it in detail and are pleased to share our proposal.\n\n'
            + 'We will deliver the ' + bid.Modules__r.size() + ' modules in the scope in about '
            + bid.Duration_Weeks__c + ' weeks with a dedicated team of ' + bid.Team_Members__r.size()
            + ', for a total investment of ' + inr(bid.Estimated_Cost__c) + '. '
            + 'The detailed scope, team and timeline are attached.\n\n'
            + 'We would welcome a 30-minute call this week to walk you through the plan.\n\n'
            + 'Warm regards,\n' + UserInfo.getName();
    }
}
