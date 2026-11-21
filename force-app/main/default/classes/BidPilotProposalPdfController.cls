/** Extension for the BidPilotProposal Visualforce page (rendered as PDF). */
public with sharing class BidPilotProposalPdfController {

    public Bid__c bid { get; private set; }
    public List<ModuleLine> modules { get; private set; }
    public List<TeamLine> team { get; private set; }
    public List<String> sowRisks { get; private set; }
    public List<String> riskReasons { get; private set; }
    public List<Milestone> milestones { get; private set; }
    public String companyName { get; private set; }
    public String preparedBy { get; private set; }
    public String preparedOn { get; private set; }
    public String validUntil { get; private set; }
    public String totalCost { get; private set; }
    public String totalHours { get; private set; }
    public String duration { get; private set; }
    public String requested { get; private set; }
    public String riskText { get; private set; }
    public String timelineNote { get; private set; }
    public Boolean hasSowRisks { get; private set; }
    public Boolean hasRiskReasons { get; private set; }
    public Boolean hasApproval { get; private set; }
    public Integer highCount { get; private set; }
    public Integer openCount { get; private set; }

    public class ModuleLine {
        public Integer num { get; set; }
        public String name { get; set; }
        public String complexity { get; set; }
        public String skill { get; set; }
        public String hours { get; set; }
        public String description { get; set; }
    }

    public class TeamLine {
        public String name { get; set; }
        public String role { get; set; }
        public String skill { get; set; }
        public String allocation { get; set; }
        public String hours { get; set; }
        public String cost { get; set; }
    }

    public class Milestone {
        public String name { get; set; }
        public String pct { get; set; }
        public String amount { get; set; }
        public String week { get; set; }
    }

    public BidPilotProposalPdfController(ApexPages.StandardController sc) {
        bid = BidPilotService.getBid(sc.getId());
        List<Organization> org = [SELECT Name FROM Organization LIMIT 1];
        companyName = org.isEmpty() ? 'Our company' : org[0].Name;
        preparedBy = [SELECT Name FROM User WHERE Id = :bid.OwnerId].Name;
        preparedOn = Date.today().format();
        validUntil = Date.today().addDays(30).format();

        Decimal cost = BidPilotService.nz(bid.Estimated_Cost__c);
        totalCost = BidPilotService.inr(cost);
        totalHours = BidPilotService.nz(bid.Total_Effort_Hours__c).setScale(0).format();
        duration = bid.Duration_Weeks__c == null ? 'TBD' : bid.Duration_Weeks__c.format() + ' weeks';
        requested = bid.Requested_Timeline_Weeks__c == null ? 'Not specified' : bid.Requested_Timeline_Weeks__c.format() + ' weeks';
        riskText = bid.Risk_Level__c == null ? 'Not assessed' : bid.Risk_Level__c + ' (' + bid.Risk_Score__c + '/100)';
        timelineNote = (bid.Duration_Weeks__c != null && bid.Requested_Timeline_Weeks__c != null
                && bid.Duration_Weeks__c > bid.Requested_Timeline_Weeks__c)
            ? 'Our plan needs more time than the requested timeline. We recommend a phased go-live or a revised date, as described in the risks section.'
            : 'The plan fits within the requested timeline.';
        hasApproval = String.isNotBlank(bid.Approval_Comments__c);

        modules = new List<ModuleLine>();
        highCount = 0;
        Integer i = 1;
        for (Bid_Module__c m : bid.Modules__r) {
            ModuleLine l = new ModuleLine();
            l.num = i++;
            l.name = m.Name;
            l.complexity = m.Complexity__c;
            l.skill = m.Skill__c;
            l.hours = BidPilotService.nz(m.Effort_Hours__c).setScale(0).format();
            l.description = m.Description__c;
            if (m.Complexity__c == 'High') highCount++;
            modules.add(l);
        }

        team = new List<TeamLine>();
        openCount = 0;
        for (Bid_Team_Member__c t : bid.Team_Members__r) {
            TeamLine l = new TeamLine();
            Boolean open = t.Resource__c == null;
            if (open) openCount++;
            Decimal rate = (!open && t.Resource__r.Hourly_Rate__c != null) ? t.Resource__r.Hourly_Rate__c : BidPilotService.DEFAULT_RATE;
            l.name = open ? 'To be onboarded' : t.Resource__r.Name;
            l.role = t.Role__c;
            l.skill = t.Skill__c;
            l.allocation = BidPilotService.nz(t.Allocation__c).setScale(0) + '%';
            l.hours = BidPilotService.nz(t.Planned_Hours__c).setScale(0).format();
            l.cost = BidPilotService.inr(BidPilotService.nz(t.Planned_Hours__c) * rate);
            team.add(l);
        }

        sowRisks = splitLines(bid.Risk_Factors__c);
        riskReasons = splitLines(bid.Risk_Breakdown__c);
        hasSowRisks = !sowRisks.isEmpty();
        hasRiskReasons = !riskReasons.isEmpty();

        Decimal weeks = bid.Duration_Weeks__c == null ? 0 : bid.Duration_Weeks__c;
        milestones = new List<Milestone>{
            milestone('Project kick-off and sign-off', 30, cost, 'Week 1'),
            milestone('Build complete, UAT starts', 40, cost, 'Week ' + Math.max(1, (weeks * 0.7).round(System.RoundingMode.HALF_UP))),
            milestone('Go-live and handover', 30, cost, 'Week ' + Math.max(1, weeks.round(System.RoundingMode.CEILING)))
        };
    }

    private static Milestone milestone(String name, Integer pct, Decimal cost, String week) {
        Milestone m = new Milestone();
        m.name = name;
        m.pct = pct + '%';
        m.amount = BidPilotService.inr(cost * pct / 100);
        m.week = week;
        return m;
    }

    private static List<String> splitLines(String raw) {
        List<String> out = new List<String>();
        if (String.isBlank(raw)) return out;
        for (String l : raw.split('[\\n;]')) {
            if (String.isNotBlank(l)) out.add(l.trim());
        }
        return out;
    }
}
