/**
 * @author : Gaurav jha
 * @createdDate : 04/07/2025
 * @LastModifiedDate: 04/07/2025
 * @Description : Queueable class to insert CustomException__c records in separate transaction
 */
public class ExceptionLoggerQueueable implements Queueable {
    
    private String exceptionMessage;
    private String exceptionType;
    private String stackTraceString;
    private Integer lineNumber;
    private String relatedToId;
    private String className;
    private String methodName;
    
    public ExceptionLoggerQueueable(String message, String typeName, String stackTrace, 
                                   Integer lineNumber, String relatedToId, 
                                   String className, String methodName) {
        this.exceptionMessage = message;
        this.exceptionType = typeName;
        this.stackTraceString = stackTrace;
        this.lineNumber = lineNumber;
        this.relatedToId = relatedToId;
        this.className = className;
        this.methodName = methodName;
    }
    
    public void execute(QueueableContext context) {
        try {
            // Capture governor limits at the time of queueable execution
            String QueryLimit = '1. SOQL Queries used / SOQL Queries allowed: ' + 
                               Limits.getQueries() + '/' + Limits.getLimitQueries();
            String DMLimit = '2. Number of records queried so far / Number allowed: ' + 
                            Limits.getDmlRows() + '/' + Limits.getLimitDmlRows();
            String DMLStat = '3. Number of DML statements used so far / Number allowed: ' + 
                            Limits.getDmlStatements() + '/' + Limits.getLimitDmlStatements();
            String CPUT = '4. Amount of CPU time (in ms) used so far / CPU usage time (in ms) allowed: ' + 
                         Limits.getCpuTime() + '/' + Limits.getLimitCpuTime();
            
            // Create CustomException__c record
            CustomException__c exc = new CustomException__c();
            exc.Related_To_Number__c = relatedToId;
            exc.Govt_Limit_in_Executing_Code__c = String.format('{0}\n{1}\n{2}\n{3}', 
                                                               new List<String>{QueryLimit, DMLimit, DMLStat, CPUT});
            exc.Exception_Message__c = exceptionMessage;
            exc.Exception_Type__c = exceptionType;
            exc.Line_Number__c = lineNumber;
            exc.StackTrace__c = stackTraceString;
            exc.MethodName__c = methodName;
            exc.ClassName__c = className;
            
            // Insert in separate transaction - this will persist even if original transaction rolls back
            insert exc;
            
            System.debug(LoggingLevel.INFO, 'CustomException successfully logged with ID: ' + exc.Id + 
                        ' in queueable context at ' + System.now());
            
        } catch (Exception queueEx) {
            // Log to system debug if insert fails - this helps with troubleshooting
            System.debug(LoggingLevel.ERROR, 'ExceptionLoggerQueueable failed to insert CustomException__c: ' + 
                        queueEx.getMessage());
            System.debug(LoggingLevel.ERROR, 'Original exception details - Message: ' + exceptionMessage + 
                        ', Type: ' + exceptionType + ', Line: ' + lineNumber);
        }
    }
}