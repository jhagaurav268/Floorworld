public class WorkOrderTriggerHandler {
    public static void createServiceAppointment(List<WorkOrder> workOrders){
        List<ServiceAppointment> serviceAppointmentList = new List<ServiceAppointment>();
        for(workOrder wrkObj: workOrders){            
            ServiceAppointment newSA = new ServiceAppointment();            
            newSA.ParentRecordId = wrkObj.Id;            
            newSA.Status = 'NONE';
            newSA.Duration = 0.5;             
            newSA.EarliestStartTime = System.now();            
            newSA.DueDate = System.now().addDays(7); 
            serviceAppointmentList.add(newSA); 
        } 
        if(serviceAppointmentList!=null){
            insert serviceAppointmentList;
        }
    }
    public static void createSurveyInvitations(List<WorkOrder> WorkOrders) {
        Survey testSurvey = [SELECT Id FROM Survey WHERE Name = 'Site Visit' LIMIT 1];
        Network community = [SELECT Id, Name, UrlPathPrefix FROM Network WHERE Name = 'Surveys' LIMIT 1];
        List<SurveyInvitation> invitationsToInsert = new List<SurveyInvitation>();
        Set<Id> workOrderIds = new Set<Id>();
        
        for (WorkOrder wo : WorkOrders) {
            workOrderIds.add(wo.Id);
            SurveyInvitation invite = new SurveyInvitation();
            invite.Name = wo.Id+' '+Date.today();
            invite.SurveyId = testSurvey.Id;
            invite.Work_Order__c = wo.Id;
            invite.CommunityId = community.Id;
            invite.OptionsAllowGuestUserResponse = true;
            invitationsToInsert.add(invite);
        }
        
        if (!invitationsToInsert.isEmpty()) {
            insert invitationsToInsert;
        }
        
        List<SurveyInvitation> insertedInvitations = [SELECT Id, Work_Order__c, InvitationLink FROM SurveyInvitation WHERE 
                                                      Work_Order__c IN :workOrderIds]; 
        
        List<WorkOrder> workOrdersToUpdate = new List<WorkOrder>();
        
        for (SurveyInvitation invitation : insertedInvitations) {
            if (invitation.Work_Order__c != null && invitation.InvitationLink != null) {
                WorkOrder wo = new WorkOrder(Id = invitation.Work_Order__c);
                wo.Survey_URL__c = invitation.InvitationLink;
                workOrdersToUpdate.add(wo);
            }
        }
        
        if (!workOrdersToUpdate.isEmpty()) {
            update workOrdersToUpdate;
        }
    }
}