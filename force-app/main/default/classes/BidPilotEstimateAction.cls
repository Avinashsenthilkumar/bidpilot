public with sharing class BidPilotEstimateAction {

    public class Request {
        @InvocableVariable(label='Bid Reference' description='Bid number (e.g. BID-0001) or Bid record Id' required=true)
        public String bidReference;
    }

    public class Response {
        @InvocableVariable(label='Total Effort Hours' description='Total estimated hours including QA and PM')
        public Decimal totalHours;
        @InvocableVariable(label='Calibration Factor' description='Actual/planned ratio from similar past projects')
        public Decimal calibrationFactor;
        @InvocableVariable(label='Similar Projects' description='Past projects used for calibration')
        public String similarProjects;
        @InvocableVariable(label='Message' description='Summary of the estimate')
        public String message;
    }

    @InvocableMethod(
        label='BidPilot: Estimate Effort'
        description='Estimates effort for every module of the bid, calibrated against similar delivered projects in the org. Call after the SOW analysis is saved.'
        category='BidPilot')
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            Response res = new Response();
            try {
                Bid__c b = BidPilotService.getBid(BidPilotService.resolveBidId(r.bidReference));
                BidPilotService.EstimateResult est = BidPilotService.estimate(b);
                update b.Modules__r;

                Integer teamSize = Math.max(2, distinctSkills(b).size());
                Decimal weeks = (est.totalHours / (BidPilotService.HOURS_PER_WEEK * teamSize)).setScale(1);
                Decimal rate = averageRate();

                update new Bid__c(
                    Id = b.Id,
                    Status__c = 'Estimated',
                    Total_Effort_Hours__c = est.totalHours,
                    Calibration_Factor__c = est.calibration,
                    Similar_Projects__c = String.join(est.similar, '\n'),
                    Duration_Weeks__c = weeks,
                    Estimated_Cost__c = (est.totalHours * rate).setScale(0)
                );

                res.totalHours = est.totalHours;
                res.calibrationFactor = est.calibration;
                res.similarProjects = String.join(est.similar, '\n');
                res.message = b.Name + ': ' + est.totalHours.setScale(0) + ' hours across ' + b.Modules__r.size()
                    + ' modules (~' + weeks + ' weeks, ' + BidPilotService.inr(est.totalHours * rate) + '). '
                    + 'Calibration factor ' + est.calibration + ' from ' + est.similar.size() + ' similar project(s).';
            } catch (Exception e) {
                res.message = 'Could not estimate: ' + e.getMessage();
            }
            out.add(res);
        }
        return out;
    }

    private static Set<String> distinctSkills(Bid__c b) {
        Set<String> s = new Set<String>();
        for (Bid_Module__c m : b.Modules__r) if (String.isNotBlank(m.Skill__c)) s.add(m.Skill__c.toLowerCase());
        return s;
    }

    private static Decimal averageRate() {
        AggregateResult ar = [SELECT AVG(Hourly_Rate__c) avgRate FROM Resource__c WHERE Active__c = true AND Hourly_Rate__c > 0];
        Decimal avg = (Decimal) ar.get('avgRate');
        return avg == null ? BidPilotService.DEFAULT_RATE : avg;
    }
}
