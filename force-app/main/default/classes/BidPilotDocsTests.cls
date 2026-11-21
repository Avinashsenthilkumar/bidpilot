@IsTest
private class BidPilotDocsTests {

    @TestSetup
    static void setup() {
        Resource__c r = new Resource__c(Name = 'Arun', Role__c = 'Developer', Skills__c = 'Apex', Hourly_Rate__c = 1800, Current_Allocation__c = 0, Active__c = true);
        insert r;
        Bid__c b = new Bid__c(Client_Name__c = 'Nila Logistics', Project_Title__c = 'Portal', Requested_Timeline_Weeks__c = 4,
            Status__c = 'Approved', Total_Effort_Hours__c = 500, Estimated_Cost__c = 900000, Duration_Weeks__c = 12.5,
            Risk_Score__c = 70, Risk_Level__c = 'High', Risk_Factors__c = 'SAP docs pending\nPenalty clause',
            Risk_Breakdown__c = 'Timeline (+40)\n1 high module (+10)', Tech_Stack__c = 'Apex',
            Approval_Comments__c = 'Approved by manager');
        insert b;
        insert new Bid_Module__c(Bid__c = b.Id, Name = 'Portal', Complexity__c = 'High', Skill__c = 'Apex', Effort_Hours__c = 240, Description__c = 'B2B portal');
        insert new Bid_Module__c(Bid__c = b.Id, Name = 'Reports', Complexity__c = 'Low', Skill__c = 'Reports', Effort_Hours__c = 48);
        insert new Bid_Team_Member__c(Bid__c = b.Id, Resource__c = r.Id, Role__c = 'Developer', Skill__c = 'Apex', Allocation__c = 100, Planned_Hours__c = 240);
        insert new Bid_Team_Member__c(Bid__c = b.Id, Role__c = 'Open position', Skill__c = 'Reports', Allocation__c = 100, Planned_Hours__c = 48);
    }

    static Bid__c bid() { return [SELECT Id, SOW_Content__c FROM Bid__c LIMIT 1]; }

    @IsTest
    static void saveSowStoresTextAndFile() {
        Bid__c b = bid();
        String text = 'STATEMENT OF WORK\n\n\n\nBuild a customer portal with shipment tracking, SAP invoices and WhatsApp alerts for B2B customers.';
        String msg = BidPilotDocsController.saveSow(b.Id, text, 'Nila_SOW.pdf', EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4')));
        System.assert(msg.contains('Nila_SOW.pdf'), msg);
        System.assert(bid().SOW_Content__c.startsWith('STATEMENT OF WORK'));
        System.assertEquals(1, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :b.Id]);
    }

    @IsTest
    static void saveSowRejectsEmptyText() {
        Boolean failed = false;
        try {
            BidPilotDocsController.saveSow(bid().Id, '   ', 'scan.pdf', null);
        } catch (AuraHandledException e) {
            failed = true;
        }
        System.assert(failed, 'Empty PDF text should be rejected');
    }

    @IsTest
    static void saveProposalPdfCreatesFile() {
        Bid__c b = bid();
        Id docId = BidPilotDocsController.saveProposalPdf(b.Id);
        System.assertNotEquals(null, docId);
        System.assertEquals(1, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :b.Id]);
    }

    @IsTest
    static void pdfControllerBuildsSections() {
        Bid__c b = bid();
        Test.setCurrentPage(Page.BidPilotProposal);
        BidPilotProposalPdfController c = new BidPilotProposalPdfController(new ApexPages.StandardController(b));
        System.assertEquals(2, c.modules.size());
        System.assertEquals(2, c.team.size());
        System.assertEquals(1, c.openCount);
        System.assertEquals(1, c.highCount);
        System.assertEquals(3, c.milestones.size());
        System.assert(c.hasSowRisks && c.hasRiskReasons && c.hasApproval);
        System.assert(c.timelineNote.contains('more time'));
        System.assertEquals('Timeline (+40)', c.riskReasons[0]);
    }
}
