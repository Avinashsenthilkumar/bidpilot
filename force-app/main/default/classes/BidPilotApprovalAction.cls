public with sharing class BidPilotApprovalAction {

    public class Request {
        @InvocableVariable(label='Bid Reference' description='Bid number (e.g. BID-0001) or Bid record Id' required=true)
        public String bidReference;
        @InvocableVariable(label='Decision' description='Approve or Reject' required=true)
        public String decision;
        @InvocableVariable(label='Comments' description='Reason or conditions given by the approver')
        public String comments;
    }

    public class Response {
        @InvocableVariable(label='New Status' description='Bid status after the decision')
        public String status;
        @InvocableVariable(label='Message' description='Result of the action')
        public String message;
    }

    @InvocableMethod(
        label='BidPilot: Record Approval Decision'
        description='Records a manager approve or reject decision on a bid that is pending approval. Only use when the user clearly says they approve or reject the bid.'
        category='BidPilot')
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            Response res = new Response();
            try {
                Bid__c b = BidPilotService.getBid(BidPilotService.resolveBidId(r.bidReference));
                if (b.Status__c == 'Proposal Ready') {
                    throw new BidPilotService.BidPilotException(b.Name + ' already has a proposal.');
                }
                Boolean approve = String.isNotBlank(r.decision) && r.decision.trim().toLowerCase().startsWith('approv');
                String status = approve ? 'Approved' : 'Rejected';
                update new Bid__c(Id = b.Id, Status__c = status,
                    Approval_Comments__c = status + ' by ' + UserInfo.getName()
                        + (String.isBlank(r.comments) ? '' : ': ' + r.comments));

                // Close the open approval task
                List<Task> open = [SELECT Id FROM Task WHERE WhatId = :b.Id AND IsClosed = false AND Subject LIKE 'Approve high-risk bid%'];
                for (Task t : open) t.Status = 'Completed';
                update open;

                res.status = status;
                res.message = b.Name + ' ' + status.toLowerCase() + '.' + (approve ? ' You can now generate the proposal.' : '');
            } catch (Exception e) {
                res.message = 'Could not record the decision: ' + e.getMessage();
            }
            out.add(res);
        }
        return out;
    }
}
