/**
 * 請求書情報の承認ステータス更新処理（外部公開API）
 * POSTリクエスト
 * @param なし
 * @return RestResponse
 * @author y.muta
 * @version 1.0
 */
@RestResource(urlMapping='/InvoiceHeaderStatusUpdate/*')
// @RestResource(urlMapping='/ErrorTestAPI06/*')
global without sharing class InvoiceHeaderStatusUpdateProcessAPI {
    @HttpPost
    global static void InvoiceHeaderStatusUpdateProcessAPI() {
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

        String targetReferenceNo = '';

        // 参照番号
        String ReferenceNo;
        // 承認ステータス
        String ApprovalStatus;
        // 連携取消フラグ
        Boolean SendCancelFlg;
        // 請求書ファイルURL
        String FileURL;
        // Webhook連携実行時間
        DateTime WebhookExecutionTime;
        //バインダID
        Integer BinderId;
        //SmartDB文書ID
        String SmartDBDocId;
        
        // エラーメール文面
        String errorMailBody = '';
        Map<Id, String> errorTargetData = new Map<Id, String>();
        List<String> bodyTextList = new List<String>{System.Label.InvoiceHeader_API_Name_InvoiceHeaderApproveProcess};
        try{
            // リクエストボディ取得
            String reqString = req.requestBody.toString();

            // STATUSの"value"キーの名称変更
            String targetStatus = '"value":{';
            String replacementStatus = '"otherValue":{';
            reqString = reqString.replace(targetStatus, replacementStatus);

            // 使用しない"value"キーの名称変更
            String targetNotUse = '"value":[';
            String replacementNotUse = '"notUsedValue":[';
            reqString = reqString.replace(targetNotUse, replacementNotUse);

            system.debug('修正後のJSON情報：'+reqString);

            System.JSONParser parser = System.JSON.createParser(reqString);
            StatusData statusData = new StatusData(parser);

            // Webhook連携実行時間を取得
            WebhookExecutionTime = Datetime.valueOf(statusData.Document.executionTime);
            System.debug('WebhookExecutionTime：'+WebhookExecutionTime);
            //バインダIDを取得
            BinderId = statusData.binder.id;
            //SmartDB文書IDを取得
            SmartDBDocId = String.valueOf(statusData.document.id);
            // DocumentのItem[]を取得→Listに格納
            List<Item> itemList = new List<Item>(statusData.Document.Item);
        
            // 取得したListのオブジェクト分ループ処理
            for(Item item : itemList){
                // "key"=「NIKKEI_CHAR_150」の場合、"value"をString変数に格納
                if(item.key == 'NIKKEI_CHAR_150'){
                    ReferenceNo = item.value;
                    System.debug('ReferenceNo：'+ReferenceNo);
                // "key"=「STATUS」の場合、"otherValue"をString変数に格納
                } else if(item.key == 'STATUS'){
                    ApprovalStatus = item.otherValue.name;
                    System.debug('Status：'+ReferenceNo);
                // "key"=「COOPERATION_CANCEL」の場合、"otherValue"をString変数に格納
                } else if(item.key == 'COOPERATION_CANCEL'){
                    // "otherValue"が存在するか判別
                    if(item.otherValue != null){
                        //"otherValue"が存在する場合、連携取消フラグをtrueに設定
                        SendCancelFlg = true;
                    } else{
                        //"otherValue"が存在しない場合、連携取消フラグをfalseに設定
                        SendCancelFlg = false;
                    }
                // "key"=「FILE」の場合、"otherValue"をString変数に格納
                } else if(item.key == 'FILE'){
                    // "otherValue"が存在するか判別
                    if(item.otherValue != null){
                        FileURL = item.otherValue.id;
                    } else {
                        FileURL = '';
                    }
                }
            }

        }catch(Exception e){
            // JSON取得でエラーが発生した場合の処理
            Database.rollback(sp);

            //エラーステータスコードを設定
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('400', System.Label.Invoice_API_ErrorMessage_400)));

            // エラーメール送信
            bodyTextList.add(e.getMessage());
            errorMailBody = String.format(System.Label.Invoice_API_ErrorMail_Body_Approve_400, bodyTextList);
            sendErrorMail(errorMailBody);
            return;
        }

        try{
            //請求書情報取得
            List<InvoiceHeader__c> ivcHeaderList = [SELECT Id, 
                                                            Name, 
                                                            ApprovalStatus__c, 
                                                            SendCancelFlg__c, 
                                                            WebhookExecutionTime__c,
                                                            SmartDBStatus__c,
                                                            DocID__c,
                                                            BinderId__c
                                                    FROM InvoiceHeader__c 
                                                    WHERE Name = :ReferenceNo];

            if(!ivcHeaderList.isEmpty()){
                
                //請求書情報更新
                for(InvoiceHeader__c ivcHeader : ivcHeaderList){
                    
                    // エラーメール対応
                    errorTargetData.put(ivcHeader.Id, ivcHeader.Name);
                    
                    //JSON取得した実行時間がSFで保持する実行時間よりも後の場合、更新処理を実施
                    if(WebhookExecutionTime >= ivcHeader.WebhookExecutionTime__c || ivcHeader.WebhookExecutionTime__c == null){

                        // 連携取り消しフラグ
                        ivcHeader.SendCancelFlg__c = SendCancelFlg;
                        // 請求書ファイル ※FileURLが返ってきたときのみ更新
                        if(!String.isBlank(FileURL)){
                            ivcHeader.File__c = 'https://' + 
                                                System.label.SmartDB_domain_name + 
                                                '/hibiki/rest/2/attaches/' + 
                                                FileURL;
                        }

                        //バインダID設定
                        ivcHeader.BinderId__c = BinderId;


                        //SmartDB文書ID設定
                        ivcHeader.DocID__c = SmartDBDocId;

                        // Webhook連携実行時間
                        ivcHeader.WebhookExecutionTime__c = WebhookExecutionTime;
                        System.debug('ivcHeader.WebhookExecutionTime__c：'+ivcHeader.WebhookExecutionTime__c);
                        // 承認ステータス
                        if (ApprovalStatus==ConstUtil.INVOICEHEADER_SD_STATUS_BEFORE_APPLICATION) {
                            // 承認ステータス:未定
                            ivcHeader.ApprovalStatus__c = ConstUtil.INVOICEHEADER_STATUS_UNDECIDED;
                            // SmartDBステータス:申請前
                            ivcHeader.SmartDBStatus__c = ConstUtil.INVOICEHEADER_SD_STATUS_BEFORE_APPLICATION;
                        //ステータス='BPO確認中'の場合
                        }else if(ApprovalStatus==ConstUtil.INVOICEHEADER_SD_STATUS_BPO_CONFIRMING){
                            // 承認ステータス:未定
                            ivcHeader.ApprovalStatus__c = ConstUtil.INVOICEHEADER_STATUS_UNDECIDED;
                            // SmartDBステータス:BPO確認中
                            ivcHeader.SmartDBStatus__c = ConstUtil.INVOICEHEADER_SD_STATUS_BPO_CONFIRMING;
                        //ステータス='部長確認中'の場合
                        }else if(ApprovalStatus==ConstUtil.INVOICEHEADER_SD_STATUS_MANAGER_CONFIRMING){
                            // 承認ステータス:未定
                            ivcHeader.ApprovalStatus__c = ConstUtil.INVOICEHEADER_STATUS_UNDECIDED;
                            // SmartDBステータス:部長確認中
                            ivcHeader.SmartDBStatus__c = ConstUtil.INVOICEHEADER_SD_STATUS_MANAGER_CONFIRMING;
                        //ステータス='管理担当者確認中'の場合
                        }else if(ApprovalStatus==ConstUtil.INVOICEHEADER_SD_STATUS_ADMIN_CONFIRMING){
                            // 承認ステータス:未定
                            ivcHeader.ApprovalStatus__c = ConstUtil.INVOICEHEADER_STATUS_UNDECIDED;
                            // SmartDBステータス:管理担当者確認中
                            ivcHeader.SmartDBStatus__c = ConstUtil.INVOICEHEADER_SD_STATUS_ADMIN_CONFIRMING;
                        //ステータス='承認済'の場合
                        }else if(ApprovalStatus==ConstUtil.INVOICEHEADER_SD_STATUS_APPROVED){
                            // 承認ステータス:承認済
                            ivcHeader.ApprovalStatus__c = ConstUtil.INVOICEHEADER_STATUS_APPROVED;
                            // SmartDBステータス:承認済
                            ivcHeader.SmartDBStatus__c = ConstUtil.INVOICEHEADER_SD_STATUS_APPROVED;
                        //ステータス='ERP連携中'の場合
                        }else if(ApprovalStatus==ConstUtil.INVOICEHEADER_SD_STATUS_ERP_COORDINATING){
                            // 承認ステータス:承認済
                            ivcHeader.ApprovalStatus__c = ConstUtil.INVOICEHEADER_STATUS_APPROVED;
                            // SmartDBステータス:ERP連携中
                            ivcHeader.SmartDBStatus__c = ConstUtil.INVOICEHEADER_SD_STATUS_ERP_COORDINATING;
                        //ステータス='ERP連携完了'の場合
                        }else if(ApprovalStatus==ConstUtil.INVOICEHEADER_SD_STATUS_ERP_COORDINATED){
                            // 承認ステータス:承認済
                            ivcHeader.ApprovalStatus__c = ConstUtil.INVOICEHEADER_STATUS_APPROVED;
                            // SmartDBステータス:ERP連携完了
                            ivcHeader.SmartDBStatus__c = ConstUtil.INVOICEHEADER_SD_STATUS_ERP_COORDINATED;
                        //ステータス='赤伝票ERP連携済'の場合
                        }else if(ApprovalStatus==ConstUtil.INVOICEHEADER_SD_STATUS_RED_ERP_COORDINATED){
                            // 承認ステータス:却下
                            ivcHeader.ApprovalStatus__c = ConstUtil.INVOICEHEADER_STATUS_DISMISSED;
                            // SmartDBステータス:赤伝票ERP連携済
                            ivcHeader.SmartDBStatus__c = ConstUtil.INVOICEHEADER_SD_STATUS_RED_ERP_COORDINATED;
                        //ステータス='請求書発行済'の場合
                        }else if(ApprovalStatus==ConstUtil.INVOICEHEADER_SD_STATUS_INVOICE_ISSUED){
                            // 承認ステータス:承認済
                            ivcHeader.ApprovalStatus__c = ConstUtil.INVOICEHEADER_STATUS_APPROVED;
                            // SmartDBステータス:請求書発行済
                            ivcHeader.SmartDBStatus__c = ConstUtil.INVOICEHEADER_SD_STATUS_INVOICE_ISSUED;
                        //ステータス='振替仕訳作成済'の場合
                        }else if(ApprovalStatus==ConstUtil.INVOICEHEADER_SD_STATUS_JOURNAL_ENTRY){
                            // 承認ステータス:承認済
                            ivcHeader.ApprovalStatus__c = ConstUtil.INVOICEHEADER_STATUS_APPROVED;
                            // SmartDBステータス:振替仕訳作成済
                            ivcHeader.SmartDBStatus__c = ConstUtil.INVOICEHEADER_SD_STATUS_JOURNAL_ENTRY;
                        //ステータス='取消し'の場合
                        }else if(ApprovalStatus==ConstUtil.INVOICEHEADER_SD_STATUS_CANCELED){
                            // 承認ステータス:却下
                            ivcHeader.ApprovalStatus__c = ConstUtil.INVOICEHEADER_STATUS_DISMISSED;
                            // SmartDBステータス:取消し
                            ivcHeader.SmartDBStatus__c = ConstUtil.INVOICEHEADER_SD_STATUS_CANCELED;
                        //ステータス='再申請'の場合
                        }else if(ApprovalStatus==ConstUtil.INVOICEHEADER_SD_STATUS_RE_APPLICATION){
                            // 承認ステータス:却下
                            ivcHeader.ApprovalStatus__c = ConstUtil.INVOICEHEADER_STATUS_DISMISSED;
                            // SmartDBステータス:再申請
                            ivcHeader.SmartDBStatus__c = ConstUtil.INVOICEHEADER_SD_STATUS_RE_APPLICATION;
                        //ステータス='振替仕訳取消し'の場合
                        } else if(ApprovalStatus==ConstUtil.INVOICEHEADER_SD_STATUS_TRANSFER_JORNAL_CANCEL){
                            // 承認ステータス:却下
                            ivcHeader.ApprovalStatus__c = ConstUtil.INVOICEHEADER_STATUS_DISMISSED;
                            // SmartDBステータス:振替仕訳取消し
                            ivcHeader.SmartDBStatus__c = ConstUtil.INVOICEHEADER_SD_STATUS_TRANSFER_JORNAL_CANCEL;
                        //ステータス='ERP連携失敗'の場合
                        } else if(ApprovalStatus==ConstUtil.INVOICEHEADER_SD_STATUS_ERP_FAILURE){
                            // 承認ステータス:却下
                            ivcHeader.ApprovalStatus__c = ConstUtil.INVOICEHEADER_STATUS_DISMISSED;
                            // SmartDBステータス:ERP連携失敗
                            ivcHeader.SmartDBStatus__c = ConstUtil.INVOICEHEADER_SD_STATUS_ERP_FAILURE;
                        } else {
                            //ステータスが上記以外
                            throw new StatusException();
                        }
                    }else{
                        throw new ExecutionTimeException();
                    }

                }
                update ivcHeaderList;
                system.debug('ivcHeaderListの中身:'+ivcHeaderList);

                // 更新した請求書情報のId取得
                String InvoiceHeaderId = ivcHeaderList[0].Id;

                // 通知メール送信
                sendNotification(InvoiceHeaderId, ApprovalStatus, SendCancelFlg);
                res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('200', String.format(System.Label.Invoice_API_SuccessMessage_InvoiceApprove, new List<String>{targetReferenceNo}))));
            }else{
                // 参照番号に該当する請求先が見つからなかった場合エラー
                throw new NotFoundReferenceNoException();
            }
        }catch(NotFoundReferenceNoException e){
            Database.rollback(sp);
            //エラーステータスコードを設定
            res.statusCode = 404;
            res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('404',  String.format(System.Label.Invoice_API_ErrorMessage_404, new List<String>{targetReferenceNo}))));

            // エラーメール送信
            bodyTextList.add(e.getMessage());
            errorMailBody = String.format(System.Label.Invoice_API_ErrorMail_Body_Approve_404, bodyTextList);
            sendErrorMail(errorMailBody);
        }catch(StatusException e){
            Database.rollback(sp);
            //エラーステータスコードを設定
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('400',  String.format(System.Label.Invoice_API_ErrorMessage_400, new List<String>{targetReferenceNo}))));

            // エラーメール送信
            bodyTextList.add(e.getMessage());
            errorMailBody = String.format(System.Label.Invoice_API_ErrorMail_Body_Approve_400, bodyTextList);
            sendErrorMail(errorMailBody);
            system.debug('StatusException発生');
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
            res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('500', System.Label.Invoice_API_ErrorMessage_500)));

            system.debug('getCause:'+e.getCause());
            system.debug('getMessage:'+e.getMessage());
            system.debug('e.getLineNumber()'+e.getLineNumber());

            // エラーメール送信
            bodyTextList.add(e.getMessage());
            errorMailBody = String.format(System.Label.Invoice_API_ErrorMail_Body_Approve_500, bodyTextList);
            // エラー対象データが特定できる場合は番号とレコードページURLを載せる
            if (!errorTargetData.isEmpty()) {
                for (Id dataId : errorTargetData.keySet()) {
                    String targetNo = errorTargetData.get(dataId);
                    errorMailBody += '\r\n'+ targetNo + ' ' + URL.getSalesforceBaseUrl().toExternalForm() + '/' + dataId+ ' ';
                }
            }
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
        private binder binder;

        private StatusData(JSONParser parser){
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'document') {
                            document = new Document(parser);
                        } else if(text == 'binder'){
                            binder = new binder(parser);
                        } else {
                            System.debug(LoggingLevel.WARN, 'JSON2Apex consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }

    private class binder {
        private Integer id;
        private binder(JSONParser parser){
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
				if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
					String text = parser.getText();
					if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if(text == 'id'){
                            id = parser.getIntegerValue();
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
        private Integer id;

		private Document(JSONParser parser) {
			while (parser.nextToken() != System.JSONToken.END_OBJECT) {
				if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
					String text = parser.getText();
					if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
						if (text == 'item') {
							item = arrayOfItem(parser);
						} else if(text == 'updated_at'){
                            executionTime = parser.getText().replace('T', ' ');
                        } else if(text == 'id'){
                            id = parser.getIntegerValue();
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
		private Value otherValue;

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
						} else if (text == 'otherValue') {
							otherValue = new Value(parser);
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
		private String id;
		private String name; 
		private Boolean disabled; 

		private Value(JSONParser parser) {
			while (parser.nextToken() != System.JSONToken.END_OBJECT) {
				if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
					String text = parser.getText();
					if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
						if (text == 'id') {
							id = parser.getText();
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
    
    public class NotFoundReferenceNoException extends Exception {}
    public class StatusException extends Exception {}
    private class ExecutionTimeException extends Exception {}

    //メール通知送信
    @AuraEnabled
    public static void sendNotification(String InvoiceHeaderId, String SmartDBStatus, Boolean SendCancelFlg){
        try {
            // フローにパスする変数を設定
            Map<String, Object> inputs = new Map<String, Object>();
            inputs.put('recordId', InvoiceHeaderId);
            inputs.put('SendCancelFlg', SendCancelFlg);
            inputs.put('SmartDBStatus', SmartDBStatus);
            System.debug('★inputs:' + inputs);

            // フロー呼び出し
            Flow.Interview.Webhook_InvoiceHeader_send_notification flowVariable = new Flow.Interview.Webhook_InvoiceHeader_send_notification(inputs);
            flowVariable.start();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

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