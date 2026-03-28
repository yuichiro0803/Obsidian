/**
 * 請求先の承認ステータス更新処理（外部公開API・Webhookから呼び出し想定）
 * POSTリクエスト
 * @param なし
 * @return RestResponse
 * @author y.muta
 * @version 1.0
 */
@RestResource(urlMapping='/BillingInfoStatusUpdate/*')
// @RestResource(urlMapping='/ErrorTestAPI05/*')
global without sharing class BillingInfoStatusUpdateProcessAPI {

    @HttpPost
    global static void BillingInfoStatusUpdateProcessAPI() {
        // リクエスト定義
        RestRequest  req = RestContext.request;
        system.debug('req:'+req);
        //レスポンス定義
        RestResponse res = RestContext.response;
        system.debug('res'+res);
        //デフォルト正常コード
        res.statusCode = 200;
        res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('200', '')));
        res.addHeader('Content-Type', 'application/json;charset=UTF-8');

        //Headerを出力
        for(String str : req.headers.keySet()){
            system.debug('Header：' + str + '=' + req.headers.get(str));
        }
        
        // sp設定
        System.SavePoint sp = Database.setSavepoint();

        // 取引先コード
        String AccountCode;
        // サイト番号
        String SiteNo;
        // 承認ステータス
        String ApprovalStatus;
        // Webhook連携実行時間
        DateTime WebhookExecutionTime;

        // エラーメール文面
        String errorMailBody = '';
        Map<Id, String> errorTargetData = new Map<Id, String>();
        List<String> bodyTextList = new List<String>{System.Label.BillingInfo_API_Name_BillingInfoApproveProcess};
        try{
            system.debug('toString前のJSON：'+req.requestBody);
            // リクエストボディ取得
            String reqString = req.requestBody.toString();
            System.debug('SmartDBからのJSON情報：'+reqString);

            // "value"キーの変換 ※STATUSの"value"を"statusValue"に名称変更
            String target = '"value":{';
            String replacement = '"statusValue":{';
            reqString = reqString.replace(target, replacement);

            system.debug('修正したJSON情報：'+reqString);

            System.JSONParser parser = System.JSON.createParser(reqString);
            StatusData statusData = new StatusData(parser);

            // 取引先コード
            AccountCode = statusData.binder.id;

            String targetNo;
            // AFF取引先と顧客マスタの判別
            if(AccountCode==System.Label.approval_status_update_last_customer){
                // AFF取引先の場合
                targetNo = 'SUPPLIER_CODE';
            } else if (AccountCode==System.Label.approval_status_update_customer_master){
                // 顧客マスタの場合
                targetNo = 'SITE_NUMBER';
            } 
            System.debug('targetNoの中身：'+targetNo);

            // Webhook連携実行時間を取得
            WebhookExecutionTime = Datetime.valueOf(statusData.Document.executionTime);
            System.debug('WebhookExecutionTime：'+WebhookExecutionTime);
            // DocumentのItem[]を取得→Listに格納
            List<Item> itemList = new List<Item>(statusData.document.item);

            // 取得したListのオブジェクト分ループ処理
            for(Item item : itemList){
                system.debug('itemの中身：'+item);
                // サイト番号の値取得
                if(item.key == targetNo){
                    SiteNo = item.value;
                    system.debug('SiteNoの中身：'+SiteNo);
                // 承認ステータスの値取得
                } else if(item.key == 'STATUS'){
                    ApprovalStatus = item.statusValue.name;
                    system.debug('ApprovalStatusの中身：'+ApprovalStatus);
                }
            }

        }catch(Exception e){
            system.debug('エラー内容：'+e.getmessage());
            // JSON取得でエラーが発生した場合の処理
            Database.rollback(sp);
                
            //エラーステータスコードを設定
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('400', System.Label.BillingInfo_API_ErrorMessage_400)));
            
            // エラーメール送信
            bodyTextList.add(e.getMessage());
            errorMailBody = String.format(System.Label.BillingInfo_API_ErrorMail_Body_Approve_400, bodyTextList);
            system.debug('Exception発生 ※JSON取得');
            sendErrorMail(errorMailBody);
            return;
        }
        try{
            // 請求先レコード取得
            List<BillingInformation__c> billingInfoList = [SELECT 
                                                                Id, 
                                                                Name, 
                                                                SiteNo__c, 
                                                                ApprovalStatus__c, 
                                                                SmartDBStatus__c,
                                                                InsertUpdateFlag__c,
                                                                WebhookExecutionTime__c
                                                            FROM BillingInformation__c 
                                                            WHERE SiteNo__c = :SiteNo];
            system.debug('billingInfoListの中身：'+billingInfoList);
            
            if(!billingInfoList.isEmpty()){
                
                //請求先更新
                for(BillingInformation__c billingInfo : billingInfoList){
                    // エラーメール対応
                    errorTargetData.put(billingInfo.Id, billingInfo.Name);
                    
                    //JSON取得した実行時間がSFで保持する実行時間よりも後の場合、更新処理を実施
                    if(WebhookExecutionTime >= billingInfo.WebhookExecutionTime__c || billingInfo.WebhookExecutionTime__c == null){

                        // Webhook連携実行時間
                        billingInfo.WebhookExecutionTime__c = WebhookExecutionTime;

                        // ステータス='申請前'
                        if (ApprovalStatus==ConstUtil.BILLINGINFO_SD_STATUS_BEFORE_APPLICATION) {
                            // 承認ステータス:未定
                            billingInfo.ApprovalStatus__c = ConstUtil.BILLINGINFO_STATUS_UNDECIDED;
                            // SmartDBステータス:申請前
                            billingInfo.SmartDBStatus__c = ConstUtil.BILLINGINFO_SD_STATUS_BEFORE_APPLICATION;
                        // ステータス='BPO補完入力中'
                        }else if(ApprovalStatus==ConstUtil.BILLINGINFO_SD_STATUS_BPO_COMPLETIMG) {
                            // 承認ステータス:未定
                            billingInfo.ApprovalStatus__c = ConstUtil.BILLINGINFO_STATUS_UNDECIDED;
                            // SmartDBステータス:BPO補完入力中
                            billingInfo.SmartDBStatus__c = ConstUtil.BILLINGINFO_SD_STATUS_BPO_COMPLETIMG;
                        // ステータス='BPO確認中'
                        }else if(ApprovalStatus==ConstUtil.BILLINGINFO_SD_STATUS_BPO_CONFIRMING){
                            // 承認ステータス:未定
                            billingInfo.ApprovalStatus__c = ConstUtil.BILLINGINFO_STATUS_UNDECIDED;
                            // SmartDBステータス:BPO確認中
                            billingInfo.SmartDBStatus__c = ConstUtil.BILLINGINFO_SD_STATUS_BPO_CONFIRMING;
                        // ステータス='承認済'
                        } else if(ApprovalStatus==ConstUtil.BILLINGINFO_SD_STATUS_APPROVED) {
                            // 承認ステータス:未定
                            billingInfo.ApprovalStatus__c = ConstUtil.BILLINGINFO_STATUS_UNDECIDED;
                            // SmartDBステータス:承認済
                            billingInfo.SmartDBStatus__c = ConstUtil.BILLINGINFO_SD_STATUS_APPROVED;
                        // ステータス='ERP連携中'
                        } else if(ApprovalStatus==ConstUtil.BILLINGINFO_SD_STATUS_ERP_COORDINATING) {
                            // 承認ステータス:未定
                            billingInfo.ApprovalStatus__c = ConstUtil.BILLINGINFO_STATUS_UNDECIDED;
                            // SmartDBステータス:ERP連携中
                            billingInfo.SmartDBStatus__c = ConstUtil.BILLINGINFO_SD_STATUS_ERP_COORDINATING;
                        // ステータス='ERP連携完了'
                        } else if(ApprovalStatus==ConstUtil.BILLINGINFO_SD_STATUS_ERP_COORDINATED) {
                            // 承認ステータス:承認済
                            billingInfo.ApprovalStatus__c = ConstUtil.BILLINGINFO_STATUS_APPROVED;
                            // SmartDBステータス:ERP連携完了
                            billingInfo.SmartDBStatus__c = ConstUtil.BILLINGINFO_SD_STATUS_ERP_COORDINATED;
                        // ステータス='再申請中'
                        } else if(ApprovalStatus==ConstUtil.BILLINGINFO_SD_STATUS_RE_APPLICATION){
                            // 承認ステータス:却下
                            billingInfo.ApprovalStatus__c = ConstUtil.BILLINGINFO_STATUS_DISMISSED;
                            // SmartDBステータス:再申請
                            billingInfo.SmartDBStatus__c = ConstUtil.BILLINGINFO_SD_STATUS_RE_APPLICATION;
                        // ステータス='ERP差戻し'
                        } else if(ApprovalStatus==ConstUtil.BILLINGINFO_SD_STATUS_ERP_RETURN){
                            // 承認ステータス:却下
                            billingInfo.ApprovalStatus__c = ConstUtil.BILLINGINFO_STATUS_DISMISSED;
                            // SmartDBステータス:ERP差戻し
                            billingInfo.SmartDBStatus__c = ConstUtil.BILLINGINFO_SD_STATUS_ERP_RETURN;
                        // ステータス='取消し'
                        } else if(ApprovalStatus==ConstUtil.BILLINGINFO_SD_STATUS_CANCELED){
                            // 承認ステータス:却下
                            billingInfo.ApprovalStatus__c = ConstUtil.BILLINGINFO_STATUS_DISMISSED;
                            // SmartDBステータス:取消し
                            billingInfo.SmartDBStatus__c = ConstUtil.BILLINGINFO_SD_STATUS_CANCELED;
                        // ステータス='BPO対応中'
                        } else if(ApprovalStatus==ConstUtil.BILLINGINFO_SD_STATUS_BPO_DEALING){
                            // 承認ステータス:却下
                            billingInfo.ApprovalStatus__c = ConstUtil.BILLINGINFO_STATUS_DISMISSED;
                            // SmartDBステータス:BPO対応中
                            billingInfo.SmartDBStatus__c = ConstUtil.BILLINGINFO_SD_STATUS_BPO_DEALING;
                        // ステータス='ERP連携失敗'
                        }else if(ApprovalStatus==ConstUtil.BILLINGINFO_SD_STATUS_ERP_FAILURE){
                            // 承認ステータス:却下
                            billingInfo.ApprovalStatus__c = ConstUtil.BILLINGINFO_STATUS_DISMISSED;
                            // SmartDBステータス:ERP連携失敗
                            billingInfo.SmartDBStatus__c = ConstUtil.BILLINGINFO_SD_STATUS_ERP_FAILURE;
                        }else {
                            //ステータスが上記以外
                            throw new StatusException();
                        }
                    }else{
                        throw new ExecutionTimeException();
                    }
                }
                update billingInfoList;

                // メール通知用の請求先情報取得
                String BillingInfoId = billingInfoList[0].Id;
                String NewUpdateFlag = billingInfoList[0].InsertUpdateFlag__c;


                sendNotification(BillingInfoId, AccountCode, ApprovalStatus, NewUpdateFlag);

                res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('200', String.format(System.Label.BillingInfo_API_SuccessMessage_BillingInfoApprove, new List<String>{SiteNo}))));
            }else{
                // サイト番号に該当する請求先が見つからなかった場合エラー
                throw new NotFoundReferenceNoException();
            }
        }catch(NotFoundReferenceNoException e){
            Database.rollback(sp);
            //エラーステータスコードを設定
            res.statusCode = 404;
            res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('404',  String.format(System.Label.BillingInfo_API_ErrorMessage_404, new List<String>{SiteNo}))));

            // エラーメール送信
            bodyTextList.add(e.getMessage());
            errorMailBody = String.format(System.Label.BillingInfo_API_ErrorMail_Body_Approve_404, bodyTextList);
            system.debug('NotFoundSiteNoException発生');
            sendErrorMail(errorMailBody);
        }catch(StatusException e){
            Database.rollback(sp);
            //エラーステータスコードを設定
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('400',  String.format(System.Label.BillingInfo_API_ErrorMessage_400, new List<String>{SiteNo}))));

            // エラーメール送信
            bodyTextList.add(e.getMessage());
            errorMailBody = String.format(System.Label.BillingInfo_API_ErrorMail_Body_Approve_400, bodyTextList);
            system.debug('StatusException発生');
            sendErrorMail(errorMailBody);
        }catch(ExecutionTimeException e){
            Database.rollback(sp);
            //エラーステータスコードを設定
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('500', System.Label.BillingInfo_API_ErrorMessage_500)));
            system.debug('ExecutionTimeException発生');
        }catch(Exception e){
            Database.rollback(sp);
            //エラーステータスコードを設定
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('500', System.Label.BillingInfo_API_ErrorMessage_500)));

            // エラーメール送信
            bodyTextList.add(e.getMessage());
            errorMailBody = String.format(System.Label.BillingInfo_API_ErrorMail_Body_Approve_500, bodyTextList);
            // エラー対象データが特定できる場合は番号とレコードページURLを載せる
            if (!errorTargetData.isEmpty()) {
                for (Id dataId : errorTargetData.keySet()) {
                    String targetSiteNo = errorTargetData.get(dataId);
                    errorMailBody += '\r\n'+ targetSiteNo + ' ' + URL.getSalesforceBaseUrl().toExternalForm() + '/' + dataId+ ' ';
                }
            }
            system.debug('エラーメッセージ：'+e.getMessage());
            system.debug('Exception発生 ※更新時');
            sendErrorMail(errorMailBody);
        }
    }

    // レスポンス用JSONクラス
    private class ResponseJSONClass {
        private String code;
        private String message;
        private ResponseJSONClass(String code, String message){
            this.code = code;
            this.message = message;
        }
    }

    // JSON取得クラス   
    private class StatusData{
        private Document document;
        private Binder binder;

        private StatusData(JSONParser parser){
            system.debug('parser.nextToken()'+parser.nextToken());
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'document') {
                            document = new Document(parser);
                        } else if(text == 'binder'){
                            binder = new Binder(parser);
                        } else {
                            System.debug(LoggingLevel.WARN, 'JSON2Apex consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }

    private class Binder {
        private String id;
        private Binder(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'id') {
                            id = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'Document consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }

    private class Document {
        private List<Item> item;
        private String executionTime;

        private Document(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'item') {
                            item = arrayOfItem(parser);
                        } else if(text == 'updated_at'){
                            executionTime = parser.getText().replace('T', ' ');
                        } else {
                            System.debug(LoggingLevel.WARN, 'Document consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    private static List<Item> arrayOfItem(System.JSONParser p) {
        List<Item> res = new List<Item>();
        if (p.getCurrentToken() == null) p.nextToken();
        while (p.nextToken() != System.JSONToken.END_ARRAY) {
            res.add(new Item(p));
        }
        return res;
    }


    private static void consumeObject(System.JSONParser parser) {
        Integer depth = 0;
        do {
            System.JSONToken curr = parser.getCurrentToken();
            if (curr == System.JSONToken.START_OBJECT || 
                curr == System.JSONToken.START_ARRAY) {
                depth++;
            } else if (curr == System.JSONToken.END_OBJECT ||
                curr == System.JSONToken.END_ARRAY) {
                depth--;
            }
        } while (depth > 0 && parser.nextToken() != null);
    }

    private class Item {
        private Integer id;
        private String key;
        private String name;
        private String value;
        private Value statusValue;

        private Item(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'id') {
                            id = parser.getIntegerValue();
                        } else if (text == 'key') {
                            key = parser.getText();
                        } else if (text == 'name') {
                            name = parser.getText();
                        } else if (text == 'value') {
                            value = parser.getText();
                        } else if (text == 'statusValue') {
                            statusValue = new Value(parser);
                        } else {
                            System.debug(LoggingLevel.WARN, 'Item consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }

    private class Value {
        private Integer id;
        private String name; 
        private Boolean disabled; 

        private Value(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'id') {
                            id = parser.getIntegerValue();
                        } else if (text == 'name') {
                            name = parser.getText();
                        } else if (text == 'disabled') {
                            disabled = parser.getBooleanValue();
                        } else {
                            System.debug(LoggingLevel.WARN, 'StatusValue consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }

    private class NotFoundReferenceNoException extends Exception {}
    private class StatusException extends Exception {}
    private class ExecutionTimeException extends Exception {}

    //メール通知送信
    @AuraEnabled
    public static void sendNotification(String BillingInfoId, String AccountCode, String SmartDBStatus, String NewUpdateFlag){
        try {
            // フローにパスする変数を設定
            Map<String, Object> inputs = new Map<String, Object>();
            inputs.put('recordId', BillingInfoId);
            inputs.put('AccountCode', AccountCode);
            inputs.put('SmartDBStatus', SmartDBStatus);
            inputs.put('NewUpdateFlag', NewUpdateFlag);
            System.debug('★inputs:' + inputs);

            // フロー呼び出し
            Flow.Interview.Webhook_BillingInfo_send_notification flowVariable = new Flow.Interview.Webhook_BillingInfo_send_notification(inputs);
            flowVariable.start();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // エラーメール送信
    private static void sendErrorMail(String mailBody){

        String addressString = System.Label.BillingInfo_API_ErrorMail_Address;
        String subjectString = System.Label.BillingInfo_API_ErrorMail_Subject;
        // String bodyString = System.Label.BillingInfo_API_ErrorMail_Body;

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        // 宛先をカンマで分割
        List<String> addressList = addressString.split(',', 0);
        mail.setToAddresses(addressList);
        // 件名
        mail.setSubject(subjectString);
        // 本文にエラーメッセージを挿入
        // List<String> bodyTextList = new List<String>{System.Label.BillingInfo_API_Name_BillingInfoApproveProcess,errorMessage};
        // mail.setPlainTextBody(String.format(bodyString, bodyTextList));
        mail.setPlainTextBody(mailBody);
        // 送信
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
    }
}