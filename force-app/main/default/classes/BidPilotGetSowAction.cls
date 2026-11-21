public with sharing class BidPilotGetSowAction {

    public static final Integer MIN_WORDS = 100;

    public class Request {
        @InvocableVariable(label='Bid Reference' description='Bid number (e.g. BID-0001) or Bid record Id' required=true)
        public String bidReference;
    }

    public class Response {
        @InvocableVariable(label='Bid Id' description='Record Id of the bid')
        public Id bidId;
        @InvocableVariable(label='Bid Number' description='Bid number')
        public String bidNumber;
        @InvocableVariable(label='Client Name' description='Client company')
        public String clientName;
        @InvocableVariable(label='Project Title' description='Project title')
        public String projectTitle;
        @InvocableVariable(label='SOW Content' description='Full SOW text to analyse')
        public String sowContent;
        @InvocableVariable(label='Requested Timeline (Weeks)' description='Timeline requested by the client')
        public Decimal requestedTimelineWeeks;
        @InvocableVariable(label='Status' description='Current bid status')
        public String status;
        @InvocableVariable(label='Message' description='Result of the action')
        public String message;
    }

    @InvocableMethod(
        label='BidPilot: Get SOW Content'
        description='Returns the SOW text and details of an existing bid so it can be analysed. Always call this before analysing a bid.'
        category='BidPilot')
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            Response res = new Response();
            try {
                Bid__c b = BidPilotService.getBid(BidPilotService.resolveBidId(r.bidReference));
                res.bidId = b.Id;
                res.bidNumber = b.Name;
                res.clientName = b.Client_Name__c;
                res.projectTitle = b.Project_Title__c;
                res.requestedTimelineWeeks = b.Requested_Timeline_Weeks__c;
                res.status = b.Status__c;
                Integer words = String.isBlank(b.SOW_Content__c) ? 0 : b.SOW_Content__c.trim().split('\\s+').size();
                if (words < MIN_WORDS) {
                    res.message = b.Name + ' has no usable SOW (only ' + words + ' words). Do NOT analyse or invent scope. '
                        + 'Ask the user to upload the SOW PDF on the bid page (Upload SOW PDF) or paste the SOW text, then try again.';
                    out.add(res);
                    continue;
                }
                res.sowContent = b.SOW_Content__c;
                res.message = 'Loaded ' + b.Name + ' (' + words + ' words). Analyse only what this SOW says.';
            } catch (Exception e) {
                res.message = e.getMessage();
            }
            out.add(res);
        }
        return out;
    }
}
