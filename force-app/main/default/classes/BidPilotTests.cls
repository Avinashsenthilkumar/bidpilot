@IsTest
private class BidPilotTests {

    @TestSetup
    static void setup() {
        insert new List<Resource__c>{
            new Resource__c(Name = 'Arun', Role__c = 'Salesforce Developer', Skills__c = 'Apex, LWC, Flow', Hourly_Rate__c = 1800, Current_Allocation__c = 20, Active__c = true),
            new Resource__c(Name = 'Divya', Role__c = 'Experience Cloud Specialist', Skills__c = 'Experience Cloud, LWC', Hourly_Rate__c = 2000, Current_Allocation__c = 50, Active__c = true),
            new Resource__c(Name = 'Karthik', Role__c = 'Project Manager', Skills__c = 'Agile, Delivery', Hourly_Rate__c = 2500, Current_Allocation__c = 40, Active__c = true)
        };
        insert new List<Past_Project__c>{
            new Past_Project__c(Name = 'Portal Revamp', Client_Name__c = 'Acme', Skills__c = 'Experience Cloud, Apex', Planned_Effort_Hours__c = 800, Actual_Effort_Hours__c = 1000),
            new Past_Project__c(Name = 'Field App', Client_Name__c = 'Beta', Skills__c = 'LWC', Planned_Effort_Hours__c = 400, Actual_Effort_Hours__c = 440)
        };
    }

    static String createBid(Integer weeks) {
        BidPilotCreateBidAction.Request r = new BidPilotCreateBidAction.Request();
        r.clientName = 'Nila Logistics';
        r.projectTitle = 'Customer Portal';
        String para = 'Build a B2B customer portal with shipment tracking, SAP invoice integration, WhatsApp notifications, '
            + 'case management for support agents, data migration from the legacy helpdesk and management dashboards. ';
        r.sowText = para.repeat(6);
        r.requestedTimelineWeeks = weeks;
        BidPilotCreateBidAction.Response res = BidPilotCreateBidAction.run(new List<BidPilotCreateBidAction.Request>{ r })[0];
        System.assertNotEquals(null, res.bidId, res.message);
        return res.bidNumber;
    }

    static void analyse(String bidNo, String json) {
        BidPilotSaveAnalysisAction.Request r = new BidPilotSaveAnalysisAction.Request();
        r.bidReference = bidNo;
        r.modulesJson = json;
        r.techStack = 'Experience Cloud, Apex, MuleSoft';
        r.riskFactors = 'SAP API documentation not shared\nPenalty clause for delays\nScope of reports is vague';
        BidPilotSaveAnalysisAction.Response res = BidPilotSaveAnalysisAction.run(new List<BidPilotSaveAnalysisAction.Request>{ r })[0];
        System.assert(res.moduleCount > 0, res.message);
    }

    static String req(String bidNo) { return bidNo; }

    @IsTest
    static void endToEndHighRisk() {
        String bidNo = createBid(4);

        BidPilotGetSowAction.Request g = new BidPilotGetSowAction.Request();
        g.bidReference = bidNo.toLowerCase();
        BidPilotGetSowAction.Response gr = BidPilotGetSowAction.run(new List<BidPilotGetSowAction.Request>{ g })[0];
        System.assertEquals('Nila Logistics', gr.clientName);

        analyse(bidNo, '```json\n[{"name":"Customer Portal","complexity":"High","skill":"Experience Cloud","description":"Self service"},'
            + '{"name":"SAP Integration","complexity":"complex","skill":"Integration"},'
            + '{"name":"Tracking LWC","complexity":"medium","skill":"LWC"}]\n```');

        BidPilotEstimateAction.Request e = new BidPilotEstimateAction.Request();
        e.bidReference = bidNo;
        BidPilotEstimateAction.Response er = BidPilotEstimateAction.run(new List<BidPilotEstimateAction.Request>{ e })[0];
        System.assert(er.totalHours > 0, er.message);
        System.assert(er.calibrationFactor > 1, 'calibration should reflect overruns');

        BidPilotSuggestTeamAction.Request t = new BidPilotSuggestTeamAction.Request();
        t.bidReference = bidNo;
        BidPilotSuggestTeamAction.Response tr = BidPilotSuggestTeamAction.run(new List<BidPilotSuggestTeamAction.Request>{ t })[0];
        System.assert(tr.skillGaps.contains('Integration'), tr.message);

        BidPilotAssessRiskAction.Request k = new BidPilotAssessRiskAction.Request();
        k.bidReference = bidNo;
        BidPilotAssessRiskAction.Response kr = BidPilotAssessRiskAction.run(new List<BidPilotAssessRiskAction.Request>{ k })[0];
        System.assertEquals('High', kr.riskLevel, kr.breakdown);
        System.assert(kr.requiresApproval);

        // Proposal blocked until approved
        BidPilotGenerateProposalAction.Request p = new BidPilotGenerateProposalAction.Request();
        p.bidReference = bidNo;
        BidPilotGenerateProposalAction.Response blocked = BidPilotGenerateProposalAction.run(new List<BidPilotGenerateProposalAction.Request>{ p })[0];
        System.assertEquals(null, blocked.opportunityId);

        Bid__c bid = [SELECT Id FROM Bid__c WHERE Name = :bidNo];
        String msg = BidPilotDashboardController.decide(bid.Id, 'Approve', 'Add 2 weeks buffer');
        System.assert(msg.contains('approved'), msg);

        BidPilotGenerateProposalAction.Response done = BidPilotGenerateProposalAction.run(new List<BidPilotGenerateProposalAction.Request>{ p })[0];
        System.assertNotEquals(null, done.opportunityId, done.message);
        System.assert(done.emailDraft.contains('Nila Logistics'));

        BidPilotDashboardController.BidData d = BidPilotDashboardController.getBidData(bid.Id);
        System.assertEquals('Proposal Ready', d.status);
        System.assertEquals(3, d.modules.size());
        System.assert(d.team.size() >= 3);
        System.assertEquals(3, [SELECT COUNT() FROM Task WHERE WhatId = :done.opportunityId]);

        // Approval after proposal is rejected
        String again = BidPilotDashboardController.decide(bid.Id, 'Reject', null);
        System.assert(again.contains('already'), again);
    }

    @IsTest
    static void lowRiskAutoApproves() {
        String bidNo = createBid(52);
        analyse(bidNo, '{"modules":[{"name":"Lead Form","complexity":"Low","skill":"LWC"}]}');
        Bid__c b = [SELECT Id FROM Bid__c WHERE Name = :bidNo];
        update new Bid__c(Id = b.Id, Risk_Factors__c = null);

        BidPilotEstimateAction.Request e = new BidPilotEstimateAction.Request();
        e.bidReference = b.Id;
        BidPilotEstimateAction.run(new List<BidPilotEstimateAction.Request>{ e });
        BidPilotSuggestTeamAction.Request t = new BidPilotSuggestTeamAction.Request();
        t.bidReference = b.Id;
        BidPilotSuggestTeamAction.run(new List<BidPilotSuggestTeamAction.Request>{ t });
        BidPilotAssessRiskAction.Request k = new BidPilotAssessRiskAction.Request();
        k.bidReference = b.Id;
        BidPilotAssessRiskAction.Response kr = BidPilotAssessRiskAction.run(new List<BidPilotAssessRiskAction.Request>{ k })[0];
        System.assertEquals(false, kr.requiresApproval, kr.breakdown);
        System.assertEquals('Approved', [SELECT Status__c FROM Bid__c WHERE Id = :b.Id].Status__c);
    }

    @IsTest
    static void shortSowIsRejected() {
        insert new Bid__c(Client_Name__c = 'Tiny Co', Project_Title__c = 'Stub', SOW_Content__c = 'just three words');
        String bidNo = [SELECT Name FROM Bid__c WHERE Client_Name__c = 'Tiny Co'].Name;
        BidPilotGetSowAction.Request g = new BidPilotGetSowAction.Request();
        g.bidReference = bidNo;
        BidPilotGetSowAction.Response gr = BidPilotGetSowAction.run(new List<BidPilotGetSowAction.Request>{ g })[0];
        System.assertEquals(null, gr.sowContent);
        System.assert(gr.message.contains('no usable SOW'), gr.message);

        BidPilotSaveAnalysisAction.Request a = new BidPilotSaveAnalysisAction.Request();
        a.bidReference = bidNo;
        a.modulesJson = '[{"name":"Scope Definition","complexity":"High","skill":"Flow"}]';
        BidPilotSaveAnalysisAction.Response ar = BidPilotSaveAnalysisAction.run(new List<BidPilotSaveAnalysisAction.Request>{ a })[0];
        System.assert(ar.message.contains('no usable SOW'), ar.message);
        System.assertEquals(0, [SELECT COUNT() FROM Bid_Module__c]);
    }

    @IsTest
    static void errorPaths() {
        BidPilotGetSowAction.Request g = new BidPilotGetSowAction.Request();
        g.bidReference = 'BID-9999';
        System.assert(BidPilotGetSowAction.run(new List<BidPilotGetSowAction.Request>{ g })[0].message.contains('No Bid'));

        String bidNo = createBid(null);
        BidPilotSaveAnalysisAction.Request bad = new BidPilotSaveAnalysisAction.Request();
        bad.bidReference = bidNo;
        bad.modulesJson = 'not json';
        System.assert(BidPilotSaveAnalysisAction.run(new List<BidPilotSaveAnalysisAction.Request>{ bad })[0].message.startsWith('Could not'));

        BidPilotEstimateAction.Request e = new BidPilotEstimateAction.Request();
        e.bidReference = bidNo;
        System.assert(BidPilotEstimateAction.run(new List<BidPilotEstimateAction.Request>{ e })[0].message.startsWith('Could not'));

        BidPilotSuggestTeamAction.Request t = new BidPilotSuggestTeamAction.Request();
        t.bidReference = bidNo;
        System.assert(BidPilotSuggestTeamAction.run(new List<BidPilotSuggestTeamAction.Request>{ t })[0].message.startsWith('Could not'));

        BidPilotAssessRiskAction.Request k = new BidPilotAssessRiskAction.Request();
        k.bidReference = bidNo;
        System.assert(BidPilotAssessRiskAction.run(new List<BidPilotAssessRiskAction.Request>{ k })[0].message.startsWith('Could not'));

        System.assertEquals('High', BidPilotService.normalizeComplexity('HIGH'));
        System.assertEquals('Low', BidPilotService.normalizeComplexity('simple'));
        System.assertEquals('Medium', BidPilotService.normalizeComplexity(null));
        System.assertEquals('INR 0', BidPilotService.inr(null));
    }
}
