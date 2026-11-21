public with sharing class BidPilotAssessRiskAction {

    public class Request {
        @InvocableVariable(label='Bid Reference' description='Bid number (e.g. BID-0001) or Bid record Id' required=true)
        public String bidReference;
    }

    public class Response {
        @InvocableVariable(label='Risk Score' description='Risk score from 0 to 100')
        public Integer riskScore;
        @InvocableVariable(label='Risk Level' description='Low, Medium or High')
        public String riskLevel;
        @InvocableVariable(label='Requires Approval' description='True when a manager must approve before the proposal is generated')
        public Boolean requiresApproval;
        @InvocableVariable(label='Risk Breakdown' description='Why the bid got this score')
        public String breakdown;
        @InvocableVariable(label='Message' description='Result of the action')
        public String message;
    }

    @InvocableMethod(
        label='BidPilot: Assess Risk'
        description='Scores bid risk (timeline pressure, complexity, skill gaps, SOW risks, past overruns). High-risk bids are routed to the manager for approval; others are auto-approved. Call after the team is suggested.'
        category='BidPilot')
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            Response res = new Response();
            try {
                Bid__c b = BidPilotService.getBid(BidPilotService.resolveBidId(r.bidReference));
                if (b.Team_Members__r.isEmpty()) {
                    throw new BidPilotService.BidPilotException('Suggest a team first.');
                }
                BidPilotService.RiskResult risk = BidPilotService.assessRisk(b);
                Boolean needsApproval = risk.level == 'High';

                update new Bid__c(
                    Id = b.Id,
                    Risk_Score__c = risk.score,
                    Risk_Level__c = risk.level,
                    Risk_Breakdown__c = String.join(risk.reasons, '\n'),
                    Status__c = needsApproval ? 'Pending Approval' : 'Approved',
                    Approval_Comments__c = needsApproval ? null : 'Auto-approved by BidPilot (risk ' + risk.level + ')'
                );

                if (needsApproval) {
                    Id approver = BidPilotService.approverFor(b.OwnerId);
                    insert new Task(
                        OwnerId = approver,
                        WhatId = b.Id,
                        Subject = 'Approve high-risk bid ' + b.Name + ' - ' + b.Client_Name__c,
                        Description = 'Risk score ' + risk.score + '/100\n' + String.join(risk.reasons, '\n'),
                        Priority = 'High',
                        Status = 'Not Started',
                        ActivityDate = Date.today().addDays(1)
                    );
                    BidPilotService.notify(approver, b.Id,
                        'BidPilot: approval needed for ' + b.Name,
                        b.Client_Name__c + ' - risk ' + risk.score + '/100. ' + (risk.reasons.isEmpty() ? '' : risk.reasons[0]));
                }

                res.riskScore = risk.score;
                res.riskLevel = risk.level;
                res.requiresApproval = needsApproval;
                res.breakdown = String.join(risk.reasons, '\n');
                res.message = needsApproval
                    ? 'Risk is HIGH (' + risk.score + '/100). Sent to the manager for approval.'
                    : 'Risk is ' + risk.level + ' (' + risk.score + '/100). Auto-approved, ready for proposal.';
            } catch (Exception e) {
                res.message = 'Could not assess risk: ' + e.getMessage();
            }
            out.add(res);
        }
        return out;
    }
}
