/**
 * 請求先連携ステータス更新処理（外部公開API）
 * POSTリクエスト
 * @param なし
 * @return RestResponse
 * @author h.hayakawa
 * @version 1.0
 */
@RestResource(urlMapping='/BillingInfoApprove/*')
// @RestResource(urlMapping='/ErrorTestAPI03/*')
global class BillingInfoApproveProcessAPI {
    @HttpPost
    global static void BillingInfoApproveProcessAPI() {
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
        // JSON格納用Map<プロアクティブコード, JSON>
        Map<String, StatusDataClass> statusDataMap = new Map<String, StatusDataClass>();
        String targetSiteNo = '';
        // エラーメール文面
        String errorMailBody = '';
        Map<Id, BillingInformation__c> errorTargetData = new Map<Id, BillingInformation__c>();
        List<String> bodyTextList = new List<String>{System.Label.BillingInfo_API_Name_BillingInfoApproveProcess};

        try{
            // リクエストボディ取得
            String reqString = req.requestBody.toString();
            system.debug('★★★'+reqString);
            StatusDataClass statusClass = (StatusDataClass) JSON.deserialize(reqString, StatusDataClass.class);
            statusDataMap.put(statusClass.BillToSiteNo, statusClass);
            targetSiteNo = statusClass.BillToSiteNo;
        }catch(Exception e){
            // JSON取得でエラーが発生した場合の処理

            Database.rollback(sp);
            //エラーステータスコードを設定
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('400', System.Label.BillingInfo_API_ErrorMessage_400)));

            // エラーメール送信
            bodyTextList.add(e.getMessage());
            errorMailBody = String.format(System.Label.BillingInfo_API_ErrorMail_Body_Approve_400, bodyTextList);
            sendErrorMail(errorMailBody);
            return;
        }
        try{
            //請求先取得
            List<BillingInformation__c> billInfoList = [SELECT Id, SiteNo__c, SendStatus__c, ErrorDetail__c 
                                                        FROM BillingInformation__c 
                                                        WHERE SiteNo__c IN :statusDataMap.keySet()
                                                       ];

            if(!billInfoList.isEmpty()){
                //請求先更新
                for(BillingInformation__c billInfo : billInfoList){
                    // エラーメール対応
                    errorTargetData.put(billInfo.Id, billInfo);

                    StatusDataClass statusData = (StatusDataClass) statusDataMap.get(billInfo.SiteNo__c);
                    if (statusData.Status==ConstUtil.APPROVE_FLAG_STATUS_SUCCESS) {
                        // 返却ステータス:成功
                        billInfo.SendStatus__c = ConstUtil.BILLINGINFO_STATUS_COORDINATED;
                        billInfo.DocID__c = statusData.DocID;
                        billInfo.ErrorDetail__c = '';
                    }else if(statusData.Status==ConstUtil.APPROVE_FLAG_STATUS_ERROR){
                        // 返却ステータス:失敗
                        billInfo.SendStatus__c = ConstUtil.BILLINGINFO_STATUS_COOPERATION_ERROR;
                        /* 空更新を回避するために削除 START */
                        // billInfo.DocID__c = statusData.DocID;
                        /* 空更新を回避するために削除 END */
                        billInfo.ErrorDetail__c = statusData.ErrorDetail;
                    }else{
                        // 返却ステータス:成功/失敗以外
                        throw new StatusException();
                    }
                }
                update billInfoList;
                res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('200', String.format(System.Label.BillingInfo_API_SuccessMessage_BillingInfoApprove, new List<String>{targetSiteNo}))));
            }else{
                // プロアクティブコードに該当する請求先が見つからなかった場合エラー
                throw new NotFoundSiteNoException();
            }
        }catch(NotFoundSiteNoException e){
            Database.rollback(sp);
            //エラーステータスコードを設定
            res.statusCode = 404;
            res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('404',  String.format(System.Label.BillingInfo_API_ErrorMessage_404, new List<String>{targetSiteNo}))));

            // エラーメール送信
            bodyTextList.add(e.getMessage());
            errorMailBody = String.format(System.Label.BillingInfo_API_ErrorMail_Body_Approve_404, bodyTextList);
            sendErrorMail(errorMailBody);
        }catch(StatusException e){
            Database.rollback(sp);
            //エラーステータスコードを設定
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('400',  String.format(System.Label.BillingInfo_API_ErrorMessage_400, new List<String>{targetSiteNo}))));
            
            // エラーメール送信
            bodyTextList.add(e.getMessage());
            errorMailBody = String.format(System.Label.BillingInfo_API_ErrorMail_Body_Approve_400, bodyTextList);
            sendErrorMail(errorMailBody);
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
                    BillingInformation__c billInfo = errorTargetData.get(dataId);
                    errorMailBody += '\r\n'+ billInfo.SiteNo__c + ' ' + URL.getSalesforceBaseUrl().toExternalForm() + '/' + dataId+ ' ';
                }
            }
            sendErrorMail(errorMailBody);
        }
    }

    // JSON取得クラス
    private class StatusDataClass {
        public String BillToSiteNo;
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

    public class NotFoundSiteNoException extends Exception {}
    public class StatusException extends Exception {}

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