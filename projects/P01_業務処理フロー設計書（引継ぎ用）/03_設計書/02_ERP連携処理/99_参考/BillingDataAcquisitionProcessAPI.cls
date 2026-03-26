/**
 * 請求データ取得処理（外部公開API）
 * GETリクエスト
 * @param なし
 * @return RestResponse
 * @author k.chiba
 * @version 1.0
 */
@RestResource(urlMapping='/BillingDataAcquisition/*')
// @RestResource(urlMapping='/ErrorTestAPI02/*')
global class BillingDataAcquisitionProcessAPI{
    public static Map<String, Schema.sObjectField> sObjectFieldMap = InvoiceDetail__c.sObjectType.getDescribe().fields.getMap();
    public static Map<String, String> ivcDetailFieldMap = new Map<String,String>();
    public static List< String > selectfieldNameList = new List<String>();
    public static List< String > orderbyfieldNameList = new List<String>();

    @testVisible
    private static Boolean isDMLExceptionTest;

    @HttpGet
    global static void BillingDataAcquisitionProcessAPI() {
        //レスポンス定義
        RestResponse res = RestContext.response;
        //デフォルト正常コード
        res.statusCode = 200;
        res.addHeader('Content-Type', 'text/csv;charset=UTF-8;charset=UTF-8');
        //sp設定
        System.SavePoint sp = Database.setSavepoint();
        // エラーメール文面
        String errorMailBody = '';
        Map<Id, String> errorTargetData = new Map<Id, String>();
        List<String> bodyTextList = new List<String>{System.Label.Invoice_API_Name_BillingDataAcquisitionProcess};
        try{
            //ヘッダー項目を取得（同項目は設定されない想定）
            String headerString = System.Label.CSV_header_items;
            String headerString2 = System.Label.CSV_header_items2;

            //oorderby句の項目を取得（同項目は設定されない想定）
            String oorderbyString = System.Label.CSV_data_sort_order_items;
            
            List<String> headerList = headerString.split(',', 0);
            List<String> headerList2 = headerString2.split(',', 0);
            List<String> oorderbyList = oorderbyString.split(',', 0);
            
            List<String> totalHeaderList = new List<String>();
            for(String h:headerList) totalHeaderList.add(h);
            for(String h2:headerList2) totalHeaderList.add(h2);

            //請求ヘッダId
            Set<Id> InvoiceHeaderIdSet = new Set<Id>();

            //csv出力用変数
            String csvFile = '';
            // ファイル名指定
            String csvFileName = System.Label.Invoice_API_Response_FileName + Datetime.now().format('yyyyMMddHHmmss')+'.csv';
            res.addHeader('fileName', csvFileName);
            List<String> csvRowValues = new List<String>();
            
            for(String fieldName : sObjectFieldMap.keySet()){
                Schema.sObjectField sof = sObjectFieldMap.get(fieldName);
                ivcDetailFieldMap.put(sof.getDescribe().getlabel(),fieldName);
            }

            //ヘッダーチェック
            headerCheck(totalHeaderList);
            orderbyCheck(oorderbyList);
            // 請求書明細の最大取得件数+1
            Integer rowLimit = ConstUtil.INVOICEDETAIL_ROW_LIMIT + 1;

            //請求書明細、取得クエリ作成
            String strQuery = '';
            strQuery = strQuery + ' SELECT InvoiceHeader__r.Id , InvoiceHeader__r.Name ,';
            strQuery = strQuery + String.join(selectfieldNameList, ',');
            strQuery = strQuery + ' FROM ';
            strQuery = strQuery + ' InvoiceDetail__c ';
            strQuery = strQuery + ' WHERE ';
            //ステータスが確定済（未連携）のデータを取得する。
            //strQuery = strQuery + ' InvoiceHeader__r.ReferenceNo__c IN (\''+ String.join(referenceNoList, '\',\'') +'\')';
            strQuery = strQuery + ' InvoiceHeader__r.Status__c = \''+ConstUtil.INVOICEHEADER_STATUS_CONFIRMED_UNCOORDINATED+'\'';
            if (orderbyfieldNameList.size()>0) {
                strQuery = strQuery + ' ORDER BY ';
                strQuery = strQuery + String.join(orderbyfieldNameList, ',');
            }
            strQuery = strQuery + ' LIMIT ' + rowLimit;
            System.debug('******** strQuery=' + strQuery);

            //クエリ発行
            List<InvoiceDetail__c> ivcDetailData = Database.query(strQuery);
            // 最大件数を超えた場合の処理
            // 件数が最大件数+1件の場合、最後の1件と同じ参照番号のレコードを除外する
            if (ivcDetailData.size()==rowLimit) {
                String overReferenceNo = ivcDetailData[rowLimit-1].InvoiceHeader__r.Name;
                for (Integer i = rowLimit-1; i >= 0; i--) {
                    if (ivcDetailData[i].InvoiceHeader__r.Name == overReferenceNo) {
                        ivcDetailData.remove(i);
                    }else {
                        break;
                    }
                }
            }
            String csvColumnHeader = String.join(totalHeaderList, ',') + '\n';
            csvFile = csvColumnHeader;
            if(!ivcDetailData.isEmpty()){
                //CSVデータ部作成
                for(InvoiceDetail__c ivcDetail : ivcDetailData){
                    // エラーメール対応
                    errorTargetData.put(ivcDetail.InvoiceHeader__r.Id, ivcDetail.ReferenceNo__c	);

                    Integer cnt = 0;
                    String rowStr = '';
                    for(String h : totalHeaderList){
                        //ヘッダーに存在する項目の場合は、データ書き出し。ヘッダーに存在しない場合、空として書き出し。
                        if(ivcDetailFieldMap.containsKey(h)){
                            if(cnt!=0) rowStr += ',';
                            rowStr += '"';
                            if(ivcDetail.get(ivcDetailFieldMap.get(h))!=null) rowStr += ivcDetail.get(ivcDetailFieldMap.get(h));
                            rowStr += '"';
                        }else{
                            if(cnt!=0) rowStr += ',';
                            rowStr += '""';
                        }
                        cnt++;
                    }
                    //一行分として追加
                    csvRowValues.add(rowStr);
                    //請求ヘッダId格納
                    InvoiceHeaderIdSet.add(ivcDetail.InvoiceHeader__r.Id);
                }
                csvFile += String.join(csvRowValues,'\n');
            }
            res.responseBody = Blob.valueOf(csvFile);
            
            //請求ヘッダ更新
            List<InvoiceHeader__c> updateList = new List<InvoiceHeader__c>();
            for(Id InvoiceHeaderId : InvoiceHeaderIdSet){
                InvoiceHeader__c InvoiceHeader = new InvoiceHeader__c();
                InvoiceHeader.Id = InvoiceHeaderId;
                InvoiceHeader.Status__c = ConstUtil.INVOICEHEADER_STATUS_IN_COOPERATION;
                updateList.add(InvoiceHeader);
            }
            //請求ヘッダ更新
            if(updateList.size() > 0) update updateList;

            //テストクラス用にDMLExceptionを強制的に発生させる
            if (Test.isRunningTest() && isDMLExceptionTest != null && isDMLExceptionTest){
                insert new BillingInformation__c();
            }
        }catch(Exception e){
            Database.rollback(sp);
            //エラーステータスコードを設定
            res.statusCode = 500;
            res.addHeader('Content-Type', 'application/json;charset=UTF-8');
            res.responseBody = Blob.valueOf(JSON.serialize(new ResponseJSONClass('500', System.Label.Invoice_API_ErrorMessage_500)));

            // エラーメール送信
            bodyTextList.add(e.getMessage());
            errorMailBody = String.format(System.Label.Invoice_API_ErrorMail_Body_Acquisition_500, bodyTextList);
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

    private static void headerCheck(List<String> hList){
        for(String h:hList){
            if(ivcDetailFieldMap.containsKey(h)){
                selectfieldNameList.add(ivcDetailFieldMap.get(h));
            }
        }
    }

    private static void orderbyCheck(List<String> hList){
        for(String h:hList){
            if(ivcDetailFieldMap.containsKey(h)){
                orderbyfieldNameList.add(ivcDetailFieldMap.get(h));
            }
        }
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