/**
 * 請求書情報連携ステータス更新処理（外部公開API）
 * POSTリクエスト
 * @param なし
 * @return RestResponse
 * @author h.hayakawa
 * @version 1.0
 */
@RestResource(urlMapping='/CompletionFlagUpdate/*')
// @RestResource(urlMapping='/ErrorTestAPI04/*')
global class CompletionFlagUpdateProcessAPI {
    @HttpPost
    global static void CompletionFlagUpdateProcessAPI() {
        // リクエスト定義
        RestRequest  req = RestContext.request;
        //レスポンス定義
        RestResponse res = RestContext.response;
        //デフォルト正常コード
        res.statusCode = 200;
        res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('200', '')));
        res.addHeader('Content-Type', 'application/json;charset=UTF-8');

        //Headerを出力
        for(String str : req.headers.keySet()){
            system.debug('Header：' + str + '=' + req.headers.get(str));
        }
        
        //sp設定
        System.SavePoint sp = Database.setSavepoint();
        // JSON格納用Map<参照番号, JSON>
        Map<String, StatusDataClass> statusDataMap = new Map<String, StatusDataClass>();
        String targetReferenceNo = '';

        // エラーメール文面
        String errorMailBody = '';
        Map<Id, String> errorTargetData = new Map<Id, String>();
        List<String> bodyTextList = new List<String>{System.Label.Invoice_API_Name_CompletionFlagUpdateProcess};
        try{
            // リクエストボディ取得
            String reqString = req.requestBody.toString();
            // Map<String, StatusDataClass> statusDataMap = new Map<String, StatusDataClass>();
            StatusDataClass statusClass = (StatusDataClass) JSON.deserialize(reqString, StatusDataClass.class);
            statusDataMap.put(statusClass.ReferenceNo, statusClass);
            targetReferenceNo = statusClass.ReferenceNo;
        }catch(Exception e){
            // JSON取得でエラーが発生した場合の処理

            Database.rollback(sp);
            //エラーステータスコードを設定
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('400', System.Label.Invoice_API_ErrorMessage_400)));

            // エラーメール送信
            bodyTextList.add(e.getMessage());
            errorMailBody = String.format(System.Label.Invoice_API_ErrorMail_Body_Completion_400, bodyTextList);
            sendErrorMail(errorMailBody);
            return;
        }
        try{
            //請求書ヘッダ取得
            List<InvoiceHeader__c> ivcHeaderList = [SELECT Id, Name, Status__c, ErrorDetail__c FROM InvoiceHeader__c WHERE Name IN :statusDataMap.keySet()];

            if(!ivcHeaderList.isEmpty()){
                
                //請求書ヘッダ更新
                for(InvoiceHeader__c ivcHeader : ivcHeaderList){
                    // エラーメール対応
                    errorTargetData.put(ivcHeader.Id, ivcHeader.Name);

                    StatusDataClass statusData = (StatusDataClass) statusDataMap.get(ivcHeader.Name);
                    if (statusData.Status==ConstUtil.COMPLETION_FLAG_STATUS_SUCCESS) {
                        // 返却ステータス:成功
                        ivcHeader.Status__c = ConstUtil.INVOICEHEADER_STATUS_COORDINATED;
                        ivcHeader.DocID__c = statusData.DocID;
                        ivcHeader.ErrorDetail__c = '';
                    }else if(statusData.Status==ConstUtil.COMPLETION_FLAG_STATUS_ERROR){
                        // 返却ステータス:失敗
                        ivcHeader.Status__c = ConstUtil.INVOICEHEADER_STATUS_COOPERATION_ERROR;
                        /* 空更新を回避するために削除 START */
                        // ivcHeader.DocID__c = statusData.DocID;
                        /* 空更新を回避するために削除 END */
                        ivcHeader.ErrorDetail__c = statusData.ErrorDetail;
                    }else{
                        // 返却ステータス:成功/失敗以外
                        throw new StatusException();
                    }
                }
                update ivcHeaderList;
                res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('200', String.format(System.Label.Invoice_API_SuccessMessage_CompletionFlag, new List<String>{targetReferenceNo}))));
            }else{
                // 参照番号に該当する請求書ヘッダが見つからなかった場合エラー
                throw new NotFoundReferenceNoException();
            }
        }catch(NotFoundReferenceNoException e){
            Database.rollback(sp);
            //エラーステータスコードを設定
            res.statusCode = 404;
            res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('404',  String.format(System.Label.Invoice_API_ErrorMessage_404, new List<String>{targetReferenceNo}))));

            // エラーメール送信
            bodyTextList.add(e.getMessage());
            errorMailBody = String.format(System.Label.Invoice_API_ErrorMail_Body_Completion_404, bodyTextList);
            sendErrorMail(errorMailBody);
        }catch(StatusException e){
            Database.rollback(sp);
            //エラーステータスコードを設定
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('400',  String.format(System.Label.Invoice_API_ErrorMessage_400, new List<String>{targetReferenceNo}))));

            // エラーメール送信
            bodyTextList.add(e.getMessage());
            errorMailBody = String.format(System.Label.Invoice_API_ErrorMail_Body_Completion_400, bodyTextList);
            sendErrorMail(errorMailBody);
        }catch(Exception e){
            Database.rollback(sp);
            //エラーステータスコードを設定
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('500', System.Label.Invoice_API_ErrorMessage_500)));

            // エラーメール送信
            bodyTextList.add(e.getMessage());
            errorMailBody = String.format(System.Label.Invoice_API_ErrorMail_Body_Completion_500, bodyTextList);
            // エラー対象データが特定できる場合は番号とレコードページURLを載せる
            if (!errorTargetData.isEmpty()) {
                for (Id dataId : errorTargetData.keySet()) {
                    String referenceNo = errorTargetData.get(dataId);
                    errorMailBody += '\r\n'+ referenceNo + ' ' + URL.getSalesforceBaseUrl().toExternalForm() + '/' + dataId+ ' ';
                }
            }
            sendErrorMail(errorMailBody);
        }
    }

    // JSON取得クラス
    private class StatusDataClass {
        public String ReferenceNo;
        public String Status;
        public String DocID;
        public String ErrorDetail;
    }

    // レスポンス用JSONクラス
    private class ResponseJSONClass {
        public String code;
        public String message;
        public ResponseJSONClass(String code, String message){
            this.code = code;
            this.message = message;
        }
    }

    public class NotFoundReferenceNoException extends Exception {}
    public class StatusException extends Exception {}

    // エラーメール送信
    private static void sendErrorMail(String mailBody){

        String addressString = System.Label.Invoice_API_ErrorMail_Address;
        String subjectString = System.Label.Invoice_API_ErrorMail_Subject;
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