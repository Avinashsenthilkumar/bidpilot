// BidPilot backend test: runs the same actions the agent calls, on the latest bid.
// Keep the bid record page open while this runs and watch the dashboard update.
String bid = [SELECT Name FROM Bid__c ORDER BY CreatedDate DESC LIMIT 1].Name;
System.debug('Testing ' + bid);

BidPilotSaveAnalysisAction.Request a = new BidPilotSaveAnalysisAction.Request();
a.bidReference = bid;
a.modulesJson = '[{"name":"Customer Self-Service Portal","complexity":"High","skill":"Experience Cloud","description":"B2B portal with login, claims and photo upload"},'
  + '{"name":"Live Shipment Tracking","complexity":"Medium","skill":"Integration","description":"TMS REST API events and map view"},'
  + '{"name":"SAP Invoice Integration","complexity":"High","skill":"Integration","description":"Invoices and payment status from SAP S/4HANA"},'
  + '{"name":"Service Cloud Console","complexity":"Medium","skill":"Service Cloud","description":"Cases, SLA timers, assignment, escalation"},'
  + '{"name":"WhatsApp Notifications","complexity":"High","skill":"WhatsApp","description":"Pickup, delay and delivery alerts"},'
  + '{"name":"Data Migration","complexity":"Medium","skill":"Data Migration","description":"1,200 accounts, 8,000 contacts, open claims"},'
  + '{"name":"Management Dashboards","complexity":"Low","skill":"Reports","description":"Claims, SLA and CSAT dashboards"}]';
a.techStack = 'Experience Cloud, Service Cloud, MuleSoft, WhatsApp Business API';
a.riskFactors = 'SAP API documentation shared only after kick-off\nWhatsApp provider not finalised\n2% per week delay penalty on fixed price\nReport list not defined\nClient IT has one part-time contact';
System.debug(BidPilotSaveAnalysisAction.run(new List<BidPilotSaveAnalysisAction.Request>{ a })[0].message);

BidPilotEstimateAction.Request e = new BidPilotEstimateAction.Request();
e.bidReference = bid;
System.debug(BidPilotEstimateAction.run(new List<BidPilotEstimateAction.Request>{ e })[0].message);

BidPilotSuggestTeamAction.Request t = new BidPilotSuggestTeamAction.Request();
t.bidReference = bid;
System.debug(BidPilotSuggestTeamAction.run(new List<BidPilotSuggestTeamAction.Request>{ t })[0].message);

BidPilotAssessRiskAction.Request k = new BidPilotAssessRiskAction.Request();
k.bidReference = bid;
System.debug(BidPilotAssessRiskAction.run(new List<BidPilotAssessRiskAction.Request>{ k })[0].message);
