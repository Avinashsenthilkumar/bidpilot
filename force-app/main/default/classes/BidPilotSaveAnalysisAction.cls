public with sharing class BidPilotSaveAnalysisAction {

    public class Request {
        @InvocableVariable(label='Bid Reference' description='Bid number (e.g. BID-0001) or Bid record Id' required=true)
        public String bidReference;
        @InvocableVariable(
            label='Modules JSON'
            description='JSON array of scope modules extracted from the SOW. Each item: {"name": "Customer Portal", "complexity": "Low|Medium|High", "skill": "Experience Cloud", "description": "one line"}. Use one primary skill per module, e.g. Apex, LWC, Experience Cloud, Integration, Flow, React Native, Data Migration.'
            required=true)
        public String modulesJson;
        @InvocableVariable(label='Tech Stack' description='Comma separated technologies needed, e.g. Salesforce Service Cloud, Experience Cloud, MuleSoft')
        public String techStack;
        @InvocableVariable(label='Risk Factors' description='Risks found in the SOW, one per line or separated by semicolons (vague scope, third-party dependency, tight deadline, penalties, etc.)')
        public String riskFactors;
        @InvocableVariable(label='Requested Timeline (Weeks)' description='Timeline requested in the SOW, in weeks, if stated')
        public Integer requestedTimelineWeeks;
    }

    public class Response {
        @InvocableVariable(label='Module Count' description='Number of modules saved')
        public Integer moduleCount;
        @InvocableVariable(label='Message' description='Result of the action')
        public String message;
    }

    @InvocableMethod(
        label='BidPilot: Save SOW Analysis'
        description='Saves the modules, tech stack and risk factors you extracted from the SOW onto the bid. Call after reading the SOW content.'
        category='BidPilot')
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            Response res = new Response();
            Savepoint sp = Database.setSavepoint();
            try {
                Id bidId = BidPilotService.resolveBidId(r.bidReference);
                List<Bid_Module__c> modules = parseModules(bidId, r.modulesJson);
                if (modules.isEmpty()) {
                    throw new BidPilotService.BidPilotException('No modules could be read from the JSON.');
                }
                delete [SELECT Id FROM Bid_Module__c WHERE Bid__c = :bidId];
                delete [SELECT Id FROM Bid_Team_Member__c WHERE Bid__c = :bidId];
                insert modules;

                Bid__c b = new Bid__c(Id = bidId, Status__c = 'Analyzed',
                    Tech_Stack__c = r.techStack == null ? null : r.techStack.left(255),
                    Risk_Factors__c = r.riskFactors);
                if (r.requestedTimelineWeeks != null && r.requestedTimelineWeeks > 0) {
                    b.Requested_Timeline_Weeks__c = r.requestedTimelineWeeks;
                }
                update b;
                res.moduleCount = modules.size();
                res.message = 'Saved ' + modules.size() + ' modules and '
                    + BidPilotService.countLines(r.riskFactors) + ' risk factors.';
            } catch (Exception e) {
                Database.rollback(sp);
                res.message = 'Could not save analysis: ' + e.getMessage();
            }
            out.add(res);
        }
        return out;
    }

    @TestVisible
    private static List<Bid_Module__c> parseModules(Id bidId, String raw) {
        List<Bid_Module__c> out = new List<Bid_Module__c>();
        if (String.isBlank(raw)) return out;
        String cleaned = raw.trim().replace('```json', '').replace('```', '').trim();
        Object parsed = System.JSON.deserializeUntyped(cleaned);
        List<Object> items;
        if (parsed instanceof List<Object>) {
            items = (List<Object>) parsed;
        } else {
            Map<String, Object> wrapper = (Map<String, Object>) parsed;
            items = (List<Object>) wrapper.get('modules');
        }
        if (items == null) return out;
        for (Object o : items) {
            Map<String, Object> m = (Map<String, Object>) o;
            String name = str(m, 'name');
            if (String.isBlank(name)) continue;
            out.add(new Bid_Module__c(
                Bid__c = bidId,
                Name = name.left(80),
                Complexity__c = BidPilotService.normalizeComplexity(str(m, 'complexity')),
                Skill__c = String.isBlank(str(m, 'skill')) ? 'General' : str(m, 'skill').left(80),
                Description__c = str(m, 'description') == null ? null : str(m, 'description').left(255)
            ));
        }
        return out;
    }

    private static String str(Map<String, Object> m, String key) {
        for (String k : m.keySet()) {
            if (k.equalsIgnoreCase(key)) return m.get(k) == null ? null : String.valueOf(m.get(k));
        }
        return null;
    }
}
