public class WorkOrderController {
    @AuraEnabled
    public static String checkWorkStepStatus(Id recordId, Integer executionOrder) {
        SurveyInvitation surveyInv = [SELECT Id, Work_Order__c, ResponseStatus FROM SurveyInvitation WHERE Work_Order__c =:recordId  LIMIT 1]; 
        WorkOrder wo = [SELECT Id, Status,Is_Document_Upload__c FROM WorkOrder WHERE Id = :recordId LIMIT 1];
        WorkStep wrkStep = [SELECT Id, Name, Status,ExecutionOrder FROM WorkStep WHERE ParentRecordId = :recordId AND ExecutionOrder = :executionOrder LIMIT 1];
        
        if(executionOrder == 2 && wo.Status == 'New'){
            return 'Please Check-In before the survey.';
        }
        if(executionOrder == 3 && surveyInv.ResponseStatus !='Completed' && wrkStep.Status != 'Completed'){
            return 'Please complete the Survey before upload the documents';
        }
        if(executionOrder == 4 && wo.Is_Document_Upload__c != true){
            return 'Please upload the documents before the Check Out.';
        }
        
        return '';
    }
    
    @AuraEnabled
    public static void checkIn(Id recordId, String statusValue, Datetime startDateTime) {
        if (String.isBlank(recordId)) {
            throw new AuraHandledException('Record Id is required.');
        }
        
        WorkOrder wo = [SELECT Id, Status FROM WorkOrder WHERE Id = :recordId LIMIT 1];
        wo.Status = statusValue;
        update wo;
        
        ServiceAppointment srvApp = [SELECT Id,Status,Check_In__c,Check_In_Date_Time__c FROM ServiceAppointment WHERE ParentRecordId =:recordId LIMIT 1];
        srvApp.Status = 'In Progress';
        srvApp.Check_In__c = true;
        srvApp.Check_In_Date_Time__c = startDateTime;
        update srvApp;
        
        WorkStep updateWrkStep = [SELECT Id, Name, Status,ExecutionOrder FROM WorkStep WHERE ParentRecordId = :recordId AND ExecutionOrder = 1 LIMIT 1];
        updateWrkStep.Status = 'Completed';
        update updateWrkStep;
        
    }
    @AuraEnabled
    public static void checkOut(Id recordId, Integer rating, String comment) {
        if (recordId == null) {
            throw new AuraHandledException('Missing Work Order ID');
        }
        
        WorkOrder wo = [SELECT Id, Status,Is_Document_Upload__c FROM WorkOrder WHERE Id = :recordId LIMIT 1];
        wo.Status = 'Completed';
        update wo;
        
        ServiceAppointment srvApp = [SELECT Id,Status,Check_Out__c,Check_Out_Date_Time__c,Rating__c	 FROM ServiceAppointment WHERE ParentRecordId =:recordId LIMIT 1];
        srvApp.Status = 'Completed';
        srvApp.Check_Out__c = true;
        srvApp.Rating__c = rating;
        srvApp.Customer_Comments__c = comment;
        update srvApp;
        
        WorkStep updateWrkStep = [SELECT Id, Name, Status,ExecutionOrder FROM WorkStep WHERE ParentRecordId = :recordId AND ExecutionOrder = 4 LIMIT 1];
        updateWrkStep.Status = 'Completed';
        update updateWrkStep;
        
        
    }
    
    
    @AuraEnabled
    public static void saveFiles(Id recordId, String filesData) {
        System.debug('recordId-->'+recordId);
        System.debug('filesToSave --> ' + JSON.serialize(filesData));
        List<FileWrapper> filesToSave = (List<FileWrapper>) JSON.deserialize(filesData, List<FileWrapper>.class);
        System.debug(filesToSave);
        if(recordId == null || filesToSave == null || filesToSave.isEmpty()) {
            throw new AuraHandledException('Missing recordId or files to upload.');
        }
        
        List<ContentVersion> contentVersions = new List<ContentVersion>();
        for (FileWrapper file : filesToSave) {
            if (String.isBlank(file.base64Data) || String.isBlank(file.name)) {
                continue;
            }
            
            ContentVersion cv = new ContentVersion();
            cv.Title = file.name;
            cv.PathOnClient = file.name;
            cv.VersionData = EncodingUtil.base64Decode(file.base64Data);
            cv.IsMajorVersion = true;
            cv.FirstPublishLocationId = recordId;
            contentVersions.add(cv);
        }
        
        if (!contentVersions.isEmpty()) {
            insert contentVersions;
            
            WorkOrder wo = [SELECT Id, Status,Is_Document_Upload__c FROM WorkOrder WHERE Id = :recordId LIMIT 1];
            wo.Is_Document_Upload__c = true;
            update wo;
            
            
            WorkStep updateWrkStep = [SELECT Id, Name, Status,ExecutionOrder FROM WorkStep WHERE ParentRecordId = :recordId AND ExecutionOrder = 3 LIMIT 1];
            updateWrkStep.Status = 'Completed';
            update updateWrkStep;
            
        } else {
            throw new AuraHandledException('No valid files to upload.');
        }
    }
    
    
    public class FileWrapper {
        @AuraEnabled public String name;
        @AuraEnabled public String type;
        @AuraEnabled public String base64Data;
        
    }
}