public with sharing class BidPilotCreateBidAction {

    public class Request {
        @InvocableVariable(label='Client Name' description='Name of the client company that sent the SOW' required=true)
        public String clientName;
        @InvocableVariable(label='Project Title' description='Short title of the project' required=true)
        public String projectTitle;
        @InvocableVariable(label='SOW Text' description='Full text of the statement of work / RFP' required=true)
        public String sowText;
        @InvocableVariable(label='Requested Timeline (Weeks)' description='Delivery timeline the client asked for, in weeks, if mentioned')
        public Integer requestedTimelineWeeks;
    }

    public class Response {
        @InvocableVariable(label='Bid Number' description='The new bid number, e.g. BID-0001')
        public String bidNumber;
        @InvocableVariable(label='Bid Id' description='Record Id of the new bid')
        public Id bidId;
        @InvocableVariable(label='Message' description='Result of the action')
        public String message;
    }

    @InvocableMethod(
        label='BidPilot: Create Bid from SOW'
        description='Creates a new Bid record from SOW text pasted by the user. Use when the user shares a new SOW or RFP that is not yet saved as a bid.'
        category='BidPilot')
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            Response res = new Response();
            try {
                Bid__c b = new Bid__c(
                    Client_Name__c = r.clientName,
                    Project_Title__c = r.projectTitle,
                    SOW_Content__c = r.sowText,
                    Requested_Timeline_Weeks__c = r.requestedTimelineWeeks,
                    Status__c = 'Draft'
                );
                insert b;
                b = [SELECT Id, Name FROM Bid__c WHERE Id = :b.Id];
                res.bidId = b.Id;
                res.bidNumber = b.Name;
                res.message = 'Created ' + b.Name + ' for ' + r.clientName + '.';
            } catch (Exception e) {
                res.message = 'Could not create the bid: ' + e.getMessage();
            }
            out.add(res);
        }
        return out;
    }
}
