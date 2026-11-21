/**
 * Document features for the BidPilot dashboard:
 *  - saveSow: stores SOW text extracted from an uploaded PDF (pdf.js, in the browser) and attaches the original file
 *  - saveProposalPdf: renders the BidPilotProposal Visualforce page as PDF and saves it to the bid's Files
 */
public with sharing class BidPilotDocsController {

    public static final Integer MAX_SOW_CHARS = 131072;

    @AuraEnabled
    public static String saveSow(Id bidId, String sowText, String fileName, String base64Pdf) {
        String text = sowText == null ? '' : sowText.replaceAll('[ \\t]+', ' ').replaceAll('\\n{3,}', '\n\n').trim();
        if (text.length() < 50) {
            throw new AuraHandledException('Could not read text from this PDF. It may be a scanned image - paste the SOW text into the SOW Content field instead.');
        }
        Boolean truncated = text.length() > MAX_SOW_CHARS;
        try {
            update new Bid__c(Id = bidId, SOW_Content__c = text.left(MAX_SOW_CHARS));
            if (String.isNotBlank(base64Pdf)) {
                insert new ContentVersion(
                    Title = 'SOW - ' + (String.isBlank(fileName) ? 'document' : fileName.removeEndIgnoreCase('.pdf')),
                    PathOnClient = String.isBlank(fileName) ? 'SOW.pdf' : fileName,
                    VersionData = EncodingUtil.base64Decode(base64Pdf),
                    FirstPublishLocationId = bidId
                );
            }
        } catch (Exception e) {
            throw new AuraHandledException('Could not save the SOW: ' + e.getMessage());
        }
        Integer words = text.split('\\s+').size();
        return 'SOW loaded from ' + fileName + ' (' + words.format() + ' words'
            + (truncated ? ', trimmed to fit' : '') + '). Now ask BidPilot to analyse it.';
    }

    /** Called from the BidPilotSowUpload Visualforce page (pdf.js runs there with a real Web Worker). */
    @RemoteAction
    public static String uploadSow(String bidId, String sowText, String fileName, String base64Pdf) {
        try {
            return saveSow(Id.valueOf(bidId), sowText, fileName, base64Pdf);
        } catch (AuraHandledException e) {
            throw new BidPilotService.BidPilotException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Id saveProposalPdf(Id bidId) {
        try {
            Bid__c bid = [SELECT Name, Client_Name__c FROM Bid__c WHERE Id = :bidId];
            PageReference pr = Page.BidPilotProposal;
            pr.getParameters().put('id', bidId);
            Blob pdf = Test.isRunningTest() ? Blob.valueOf('test pdf') : pr.getContentAsPDF();
            ContentVersion cv = new ContentVersion(
                Title = 'Proposal - ' + bid.Client_Name__c + ' - ' + bid.Name,
                PathOnClient = 'Proposal_' + bid.Name + '.pdf',
                VersionData = pdf,
                FirstPublishLocationId = bidId
            );
            insert cv;
            return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        } catch (Exception e) {
            throw new AuraHandledException('Could not create the PDF: ' + e.getMessage());
        }
    }
}
