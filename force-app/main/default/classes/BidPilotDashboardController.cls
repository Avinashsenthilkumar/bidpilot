public with sharing class BidPilotDashboardController {

    public class ModuleRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String complexity;
        @AuraEnabled public String skill;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal hours;
    }

    public class MemberRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String role;
        @AuraEnabled public String skill;
        @AuraEnabled public Decimal allocation;
        @AuraEnabled public Decimal hours;
        @AuraEnabled public Decimal rate;
        @AuraEnabled public Decimal cost;
        @AuraEnabled public Boolean isOpen;
    }

    public class BidData {
        @AuraEnabled public String id;
        @AuraEnabled public String bidNumber;
        @AuraEnabled public String clientName;
        @AuraEnabled public String projectTitle;
        @AuraEnabled public String status;
        @AuraEnabled public String techStack;
        @AuraEnabled public Decimal totalHours;
        @AuraEnabled public Decimal cost;
        @AuraEnabled public Decimal durationWeeks;
        @AuraEnabled public Decimal requestedWeeks;
        @AuraEnabled public Decimal riskScore;
        @AuraEnabled public String riskLevel;
        @AuraEnabled public String riskFactors;
        @AuraEnabled public String riskBreakdown;
        @AuraEnabled public Decimal calibration;
        @AuraEnabled public String similarProjects;
        @AuraEnabled public String proposal;
        @AuraEnabled public String email;
        @AuraEnabled public String approvalComments;
        @AuraEnabled public String opportunityId;
        @AuraEnabled public List<ModuleRow> modules = new List<ModuleRow>();
        @AuraEnabled public List<MemberRow> team = new List<MemberRow>();
    }

    @AuraEnabled
    public static BidData getBidData(Id bidId) {
        try {
            Bid__c b = BidPilotService.getBid(bidId);
            BidData d = new BidData();
            d.id = b.Id;
            d.bidNumber = b.Name;
            d.clientName = b.Client_Name__c;
            d.projectTitle = b.Project_Title__c;
            d.status = b.Status__c;
            d.techStack = b.Tech_Stack__c;
            d.totalHours = b.Total_Effort_Hours__c;
            d.cost = b.Estimated_Cost__c;
            d.durationWeeks = b.Duration_Weeks__c;
            d.requestedWeeks = b.Requested_Timeline_Weeks__c;
            d.riskScore = b.Risk_Score__c;
            d.riskLevel = b.Risk_Level__c;
            d.riskFactors = b.Risk_Factors__c;
            d.riskBreakdown = b.Risk_Breakdown__c;
            d.calibration = b.Calibration_Factor__c;
            d.similarProjects = b.Similar_Projects__c;
            d.proposal = b.Proposal_Summary__c;
            d.email = b.Client_Email_Draft__c;
            d.approvalComments = b.Approval_Comments__c;
            d.opportunityId = b.Opportunity__c;
            for (Bid_Module__c m : b.Modules__r) {
                ModuleRow r = new ModuleRow();
                r.id = m.Id; r.name = m.Name; r.complexity = m.Complexity__c; r.skill = m.Skill__c;
                r.description = m.Description__c; r.hours = m.Effort_Hours__c;
                d.modules.add(r);
            }
            for (Bid_Team_Member__c t : b.Team_Members__r) {
                MemberRow r = new MemberRow();
                r.id = t.Id;
                r.isOpen = t.Resource__c == null;
                r.name = r.isOpen ? 'Open position' : t.Resource__r.Name;
                r.role = t.Role__c; r.skill = t.Skill__c; r.allocation = t.Allocation__c; r.hours = t.Planned_Hours__c;
                r.rate = (!r.isOpen && t.Resource__r.Hourly_Rate__c != null) ? t.Resource__r.Hourly_Rate__c : BidPilotService.DEFAULT_RATE;
                r.cost = (BidPilotService.nz(t.Planned_Hours__c) * r.rate).setScale(0);
                d.team.add(r);
            }
            return d;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String decide(Id bidId, String decision, String comments) {
        BidPilotApprovalAction.Request r = new BidPilotApprovalAction.Request();
        r.bidReference = bidId;
        r.decision = decision;
        r.comments = comments;
        return BidPilotApprovalAction.run(new List<BidPilotApprovalAction.Request>{ r })[0].message;
    }
}
