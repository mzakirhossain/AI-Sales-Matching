public with sharing class AIMatchingController {

      @AuraEnabled
    public static String startProcess() {

        String processId = String.valueOf(Crypto.getRandomInteger());

        System.enqueueJob(new AIMatchingJob(processId));

        return processId;
    }

    @AuraEnabled
    public static List<AIMatch_Result__c> getResults(String processId) {
        return [
            SELECT Lead__c,Lead__r.Name, Priority__c, Insights__c, Assigned_Agent_Name__c, Listing_log__c,CreatedDate ,Confidence__c
            FROM AIMatch_Result__c
            WHERE Process_Id__c = :processId
        ];
    }

    @AuraEnabled
    public static List<AIMatch_Result__c> getPrevResults() {
        return [
            SELECT Lead__c,Lead__r.Name, Priority__c, Insights__c, Assigned_Agent_Name__c, Listing_log__c,CreatedDate ,Confidence__c
            FROM AIMatch_Result__c order by id desc limit 50
        ];
    }


}