public class CreateInvoiceController{
    //ログインユーザ
    private User loginUser;
    // 商談Id
    public Id productId;
    // 商談名
    public String productName {get;set;}
    // 請求先情報選択用
    public InvoiceHeader__c item {get; set;}
    // 請求先情報格納用
    public Map<Id,BillingInformation__c> billingInformationMap = new Map<Id,BillingInformation__c>();
    // 請求明細（作成済み）の行番号
    public Integer rowNumberCreated {get;set;}
    public Integer rowNumberReapply {get;set;}
    // 請求明細（作成済み）のヘッダのId
    public Id editClickRowHeaderId {get; set;}
    // 請求明細（作成済み）のヘッダのName
    public String editClickRowHeaderName {get; set;}
    
    // 請求明細（作成前）の行番号
    public Integer rowNumberSelect {get;set;}

    // 作成済み明細リストから削除し、あとでヘッダをなしに更新する請求明細リスト
    public List<InvoiceDetail__c> deleteInvoiceDetailList = new List<InvoiceDetail__c>();
    //選択されていない作成済み明細リスト
    public List<InvoiceDetail__c> unselectedInvoiceDetailList = new List<InvoiceDetail__c>();

    // 作成済み明細リストで選択された明細のヘッダの更新用Map
    public Map<Id,InvoiceHeader__c> updateInvoiceHeaderMap = new Map<Id,InvoiceHeader__c>();

    // 売上情報リスト
    public List<SalesLineItem__c> oppLineItems2 = new List<SalesLineItem__c>();
    // 売上情報ラッパーリスト（マスタ）
    public List<salesLineItemObjectWrapper> salesLineItemObjectMaster = new List<salesLineItemObjectWrapper>();
    // 売上情報ラッパーリスト（未選択）
    public List<salesLineItemObjectWrapper> salesLineItemObjectSelects = new List<salesLineItemObjectWrapper>();
    // 売上情報ラッパーリスト（選択済み）
    //public List<salesLineItemObjectWrapper> salesLineItemObjectSelecteds = new List<salesLineItemObjectWrapper>();
    //売上情報ラッパーリスト（戻るボタン用） ※戻るボタン押下時に、元の売上情報一覧状態に戻すためのバックアップリスト
    List<salesLineItemObjectWrapper> SalesLineItemBackUpList = new List<salesLineItemObjectWrapper>();
    // 売上情報Map
    public Map<Id,salesLineItemObjectWrapper> mapSalesLineItemSelectedId = new Map<Id,salesLineItemObjectWrapper>();
    // 売上情報ラッパー（内部クラス）
    public class salesLineItemObjectWrapper{
        public SalesLineItem__c Record {get; private set;}  //元のオブジェクト格納
        public Boolean selected {get; set;} //チェックボックス用
        public String recordingMonth {get; set;} //計上年月（表示用）
        public String closeDate {get; set;} //完了予定日（表示用）
        public String hogeName {get; set;} //追加する項目（あれば）

        public Boolean backupSelected {get; set;}  //戻るボタン押下時の選択状態復元で使用

        public salesLineItemObjectWrapper(SalesLineItem__c record) {
            this.Record = record;
            this.selected = false; //デフォルト値
            this.recordingMonth = String.ValueOf(Record.RecordingMonth__c.Year()) + '/' + String.ValueOf(Record.RecordingMonth__c.Month()) + '/' + String.ValueOf(Record.RecordingMonth__c.Day());
            this.closeDate = String.ValueOf(Record.OpportunityId__r.CloseDate.Year()) + '/' + String.ValueOf(Record.OpportunityId__r.CloseDate.Month()) + '/' + String.ValueOf(Record.OpportunityId__r.CloseDate.Day());
            this.hogeName = '';
        }
    }

    // 請求ヘッダラッパーリスト（マスタ）
    public List<invoiceHeaderObjectWrapper> invoiceHeaderObjectMaster = new List<invoiceHeaderObjectWrapper>();
    // 請求ヘッダラッパー（内部クラス）
    public class invoiceHeaderObjectWrapper{
        public InvoiceHeader__c Record {get; private set;}  //元のオブジェクト格納
        public Integer recordNumber {get; set;} //INSERT前の一意の値 → INSERT前なのでIDがないため

        public invoiceHeaderObjectWrapper(InvoiceHeader__c record,Integer num) {
            this.Record = record;
            this.recordNumber = num;
        }
    }

    // 請求明細ラッパーリスト（作成済み）
    public List<invoiceDetailObjectWrapper> invoiceDetailObjectCreated = new List<invoiceDetailObjectWrapper>();
    // 請求明細ラッパーリスト（マスタ）
    public List<invoiceDetailObjectWrapper> invoiceDetailObjectMaster = new List<invoiceDetailObjectWrapper>();
    // 請求明細ラッパー（内部クラス）
    public class invoiceDetailObjectWrapper implements Comparable{
        public InvoiceDetail__c Record {get; private set;}  //元のオブジェクト格納
        public String relationInvoiceHeaderNumber {get; set;} // INSERT後に参照先として設定する請求ヘッダの番号

        public String Product2Name {get; set;}    //商品名
        public String Product2Detail {get; set;} //商品詳細
        public String RecordingMonth {get; set;}    //計上年月
        public Decimal RecordingPriceTotal {get; set;}   //計上金額
        public String BillingOffice {get; set;}     //請求先
        public String InvoiceDisplayName {get; set;}    //請求書表示名
        public String CustomerName {get; set;}    //顧客名
        public Integer rowSpan {get; set;}
        public Boolean rendered {get; set;}

        public invoiceDetailObjectWrapper(InvoiceDetail__c record,String product2Name,String product2Detail,Date recordingMonth,Decimal recordingPriceTotal,String recordNum, String billingOffice, String invoiceDisplayName, String customerName) {
            this.Record = record;
            this.relationInvoiceHeaderNumber = recordNum;
            system.debug('請求明細にaddしたときのヘッダ番号：'+recordNum);
            this.Product2Name = product2Name;
            this.Product2Detail = product2Detail;
            if(recordingMonth != null) {
                this.RecordingMonth = String.ValueOf(recordingMonth.Year()) + '/' + String.ValueOf(recordingMonth.Month()) + '/' + String.ValueOf(recordingMonth.Day());
            }
            this.RecordingPriceTotal = recordingPriceTotal;
            this.BillingOffice = billingOffice;
            this.InvoiceDisplayName = invoiceDisplayName;
            this.rowSpan = 1;
            this.rendered = true;
            this.CustomerName = customerName;
        }

        public void setRowSpan(Integer rowSpan) {
            this.rowSpan = rowSpan;
            if (rowSpan>0) {
                this.rendered = true;
            } else {
                this.rendered = false;
            }
        }
        public String getHeaderName(String targetTable) {
            return String.valueOf( this.relationInvoiceHeaderNumber);
        }

        // ソート用メソッド
        public Integer compareTo(Object compareTo) {
            // 比較先オブジェクト
            invoiceDetailObjectWrapper compareToIDObj = (invoiceDetailObjectWrapper)compareTo;
            
            Integer returnValue = 0;

            if (this.relationInvoiceHeaderNumber.compareTo(compareToIDObj.relationInvoiceHeaderNumber) > 0) {
                returnValue = 1;
            } else if (this.relationInvoiceHeaderNumber.compareTo(compareToIDObj.relationInvoiceHeaderNumber) < 0) {
                returnValue = -1;
            // 明細DFF1
            } else if (this.Record.DetailDFF1__c == null || compareToIDObj.Record.DetailDFF1__c == null) {
                returnValue = 1;
            } else if (this.Record.DetailDFF1__c.compareTo(compareToIDObj.Record.DetailDFF1__c) > 0){
                returnValue = 1;
            } else if (this.Record.DetailDFF1__c.compareTo(compareToIDObj.Record.DetailDFF1__c) < 0){
                returnValue = -1;
            // 売上情報.商品詳細
            } else if (this.product2Detail == null || compareToIDObj.product2Detail == null) {
                returnValue = 1;
            } else if (this.product2Detail.compareTo(compareToIDObj.product2Detail) > 0){
                returnValue = 1;
            } else if (this.product2Detail.compareTo(compareToIDObj.product2Detail) < 0){
                returnValue = -1;
            }
            return returnValue;
        }
    }

    // 初期表示処理
    public void doInitAction(){
        // ログインユーザの情報取得
        loginUser = [SELECT Department__c, EmployeeNumber__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        this.item = new InvoiceHeader__c();

        // 商談ID取得
        productId = ApexPages.currentPage().getParameters().get('id');
        // 商談名取得
        productName = ApexPages.currentPage().getParameters().get('name');
        
        // 既存の請求書ヘッダ・請求明細を取得
        List<InvoiceHeader__c> createdInvoiceHeader = new List<InvoiceHeader__c>();
        List<InvoiceDetail__c> createdInvoiceDetail = new List<InvoiceDetail__c>();
        createdInvoiceDetail = [
            SELECT
                InvoiceHeader__r.Name,                      //参照番号
                toLabel(InvoiceHeader__r.Status__c),                 //ステータス
                SalesLineItem__r.Product2Id__r.Name,        //商品
                SalesLineItem__r.Product2Detail__c,         //商品詳細
                InvoiceHeader__r.BillingOffice__r.Name,     //請求先事業所
                InvoiceHeader__r.BillingOffice__r.CustomerName__c,//顧客名
                SalesLineItem__r.RecordingMonth__c,         //計上年月
                SalesLineItem__r.RecordingPriceTotal__c,    //計上金額
                DetailDescription__c,                       //明細摘要
                InvoiceHeader__r.Opportunity__r.Owner.Name, //商談担当者(請求ヘッダ)
                SalesLineItem__r.CreatedBy.Name,            //作成者
                SalesLineItem__c,                           //売上情報
                SalesLineItem__r.OpportunityId__r.Owner.Name,    //商談担当者(売上情報)
                DetailDFF1__c,                              //明細DFF1
                DetailDFF2__c,                              //明細DFF2
                DisplayOrderNo__c,                          //表示順
                SalesLineItem__r.InvoiceDisplayName__c,     //請求書表示名
                Name
            FROM
                InvoiceDetail__c
            WHERE 
                InvoiceHeader__r.Opportunity__r.Id = :productId
            ORDER BY
                InvoiceHeader__c
        ];
        Set<Id> salesLineItemIdSet = new Set<Id>();
        // 請求明細表示処理
        for(InvoiceDetail__c obj : createdInvoiceDetail){
            invoiceDetailObjectCreated.add(
                new invoiceDetailObjectWrapper(
                    obj,
                    obj.SalesLineItem__r.Product2Id__r.Name,
                    obj.SalesLineItem__r.Product2Detail__c,
                    Date.ValueOf(obj.SalesLineItem__r.RecordingMonth__c),
                    obj.SalesLineItem__r.RecordingPriceTotal__c,
                    obj.InvoiceHeader__r.Name,
                    obj.InvoiceHeader__r.BillingOffice__r.Name,                             //TODO20230310 CustomerName__Cに戻す
                    obj.SalesLineItem__r.InvoiceDisplayName__c,
                    obj.InvoiceHeader__r.BillingOffice__r.CustomerName__c
                )
            );
            salesLineItemIdSet.add(obj.SalesLineItem__c);

        }

        invoiceDetailObjectCreated = setRowSpan(invoiceDetailObjectCreated, 'created');

        //　売上情報一覧取得
        oppLineItems2 = 
        [
            SELECT
                Id,
                Name,                       // 
                Product2Id__r.Name,         // 商品
                Product2Detail__c,          // 商品詳細
                UnitPrice__c,               // 単価
                Quantity__c,                // 数量
                RecordingPriceTotal__c,     // 計上金額
                RecordingMonth__c,          // 計上年月
                CreatedBy.Name,             // 作成者
                InvoiceDisplayName__c,      // 請求書用表示名
                OpportunityId__r.CloseDate, // 完了予定日
                BillingAmount__c,           // 請求金額
                OpportunityId__r.Owner.Name,    // 商談担当者
                TaxCode__c,                 // 税コード
                ProjectCode__c,             // プロジェクトコード
                AccountingDepartment__c,    // 計上部門
                tolabel(AccountingDepartment__c) AccountingDepartmentLabel,  //計上部門（ラベル値）
                AccountCode__c,             // 勘定科目
                ProductCode2__c,            // 商品コード
                tolabel(ProductCode2__c) ProductCode2Label,  //商品コード（ラベル値）
                RecordingMethod__c,         // 計上方法
                ContinuationMonth__c,       // 按分回数
                Unit__c,                    // 単位
                AccountName__c,             // 取引件名
                IsLocked__c,                // ロック
                Product2Detail3__c,         //商品詳細3
                Product2Detail4__c,         //商品詳細4
                Product2Detail5__c,         //商品詳細5
                Product2Detail6__c,         //商品詳細6
                Product2Detail7__c          //商品詳細7
            FROM
                SalesLineItem__c
            WHERE
                Id IN :salesLineItemIdSet
                OR (
                    IsLocked__c = FALSE
                    AND
                    OpportunityId__c = :productId
                    AND
                    InvoiceDisplayName__c != ''
                    AND
                    ProjectCode__c != ''
                    AND
                    AccountCode__c != ''
                    AND
                    Unit__c != ''
                )

                /* 以下は開発環境でデータがないときのための条件　Full・本番では切り替え必要 */
                // OR (
                //     IsLocked__c = FALSE
                //     AND
                //     Product2Detail__c != ''
                //     AND
                //     ProjectCode__c != ''
                // )
        ];

        for(SalesLineItem__c oppLineItem2 : oppLineItems2){
            salesLineItemObjectWrapper obj = new salesLineItemObjectWrapper(oppLineItem2);

            // 売上情報ロック処理 start
            // ロックされていない商談商品のみ表示
            if (!obj.Record.IsLocked__c) {
                salesLineItemObjectSelects.add(obj);
            } else {
                // ロックされている商品は選択済み
                obj.selected = true;
            }
            salesLineItemObjectMaster.add(obj);
            // 売上情報ロック処理 end
        }
    }

    // 新規請求書明細選択（請求書一覧画面）
    public void getSalesLineItemList(){
        // 請求先をクリア
        item.BillingOffice__c = null;
        // 選択状態をクリア
        salesLineItemObjectSelects.clear();

        for(salesLineItemObjectWrapper obj : salesLineItemObjectMaster){
            // 売上情報ロック処理 start
            // if(!obj.selected || !obj.Record.IsLocked__c){
            if(!obj.selected){
                salesLineItemObjectSelects.add(obj);
            }
            // 売上情報ロック処理 end
        }

        //画面表示時点の売上情報一覧の選択状態を保持 ※戻るボタン押下時に元の状態に戻すため
        SalesLineItemBackUpList = salesLineItemObjectSelects.clone();
        for( salesLineItemObjectWrapper obj : SalesLineItemBackUpList){
            obj.backupSelected = obj.selected;
        }
    }
    //ページからの参照用
    public List<salesLineItemObjectWrapper> getSalesLineItemObjectSelects() {
        return salesLineItemObjectSelects;
    }
    public List<invoiceDetailObjectWrapper> getInvoiceDetailObjectCreated() {
        return invoiceDetailObjectCreated;
    }
    public List<invoiceDetailObjectWrapper> getInvoiceDetailObjectMaster() {
        return invoiceDetailObjectMaster;
    }
    public InvoiceHeader__c getItem() {
        return item;
    }
    // public String getEditClickRowHeaderName(){
    //     return editClickRowHeaderName;
    // }

    
    // キャンセルリンク
    public PageReference invoiceReapply(){
        // 選択した行番号を取得
        rowNumberReapply = Integer.ValueOf(System.currentPageReference().getParameters().get('numberReapply'));
        // 選択した行の請求明細を取得
        invoiceDetailObjectWrapper clickInvoiceDetail = invoiceDetailObjectCreated.get(rowNumberReapply);
        
        InvoiceHeader__c header = [
            SELECT
                Id,
                Status__c,
                CancelBillingManagementScreenFlg__c
            FROM 
                InvoiceHeader__c
            WHERE
                Id = :clickInvoiceDetail.record.InvoiceHeader__c
        ];
        // ステータスが送信済みの場合は却下に設定する　それ以外はキャンセルに設定する
        if(header.Status__c == '3'){
            header.Status__c = '-2';
        } else {
            header.Status__c = '-3';
        }
        // 入力規則回避のためのフラグON
        header.CancelBillingManagementScreenFlg__c = true;
        update header;

        // フラグOFFに戻す
        header.CancelBillingManagementScreenFlg__c = false;
        update header;

        // 売上情報ロック処理 start

        // 選択した請求明細と同じ請求ヘッダを持つ請求明細に使用されている商談商品を取得
        List<Id> cancelSalesLineItemIdList = new List<Id>();
        List<SalesLineItem__c> updateSalesLineList = new List<SalesLineItem__c>();
        for(invoiceDetailObjectWrapper obj : invoiceDetailObjectCreated){
            if(obj.record.InvoiceHeader__c == clickInvoiceDetail.record.InvoiceHeader__c){
                cancelSalesLineItemIdList.add(obj.Record.SalesLineItem__c);
                // キャンセルした請求書情報の明細に紐付く売上情報のロックをfalseにする
                updateSalesLineList.add( new SalesLineItem__c(Id = obj.Record.SalesLineItem__c, IsLocked__c = false));
                // 選択済み商品Mapから消去
                mapSalesLineItemSelectedId.remove(obj.Record.SalesLineItem__c);
            }
        }
        // マスタでループ
        for(salesLineItemObjectWrapper obj2 : salesLineItemObjectMaster){
            if(cancelSalesLineItemIdList.contains(obj2.Record.Id)){
                // 選択解除する
                obj2.selected = false;
            }
        }
        // List<InvoiceDetail__c> invcDetailList = [
        //     SELECT
        //         Id,
        //         SalesLineItem__c
        //     FROM 
        //         InvoiceDetail__c
        //     WHERE
        //         InvoiceHeader__c = :header.Id
        // ];
        // for (InvoiceDetail__c invcDetail : invcDetailList) {
        //     updateSalesLineList.add( new SalesLineItem__c(Id = invcDetail.SalesLineItem__c, IsLocked__c = false));
        // }
        update updateSalesLineList;
        // 売上情報ロック処理 end

        //画面を更新する
        PageReference pr = returnCreateInvoice();
        return pr;
    }

    // 保存ボタン(売上情報一覧)
    public void selectInvoiceSave(){
        // 請求先情報取得
        BillingInformation__c tmpBillingInformation = getBillingInformation(item.BillingOffice__c);

        // Mapに格納
        billingInformationMap.put(tmpBillingInformation.Id,tmpBillingInformation);

        // 選択済みがあるかどうかの判定用
        Boolean selectedFlg = false;

        // 社員番号取得
        String employeeNumber = getOpportunity().Owner.EmployeeNumber__c;
        
        // マスタでループ
        for(salesLineItemObjectWrapper obj : salesLineItemObjectSelects){
            // 選択されている場合
            if(obj.selected){
                // 請求明細に追加済みか判定する
                if(mapSalesLineItemSelectedId.get(obj.record.Id) == null){
                    // 選択済み有フラグをTrueにする
                    selectedFlg = true;

                    // Mapに追加
                    mapSalesLineItemSelectedId.put(obj.record.Id,obj);

                    // 請求書明細に追加
                    invoiceDetailObjectMaster.add(
                        new invoiceDetailObjectWrapper(
                            new InvoiceDetail__c(
                                // 請求明細の値設定
                                // 請求ヘッダへの参照はInsert時に設定する（ここでは設定しない）
                                SalesLineItem__c = obj.Record.Id,                                           // 売上情報
                                Quantity__c = obj.Record.Quantity__c,                                       // 数量
                                UnitPrice__c = obj.Record.UnitPrice__c,                                     // 単価
                                TaxCode__c = getTaxCode(tmpBillingInformation.AccountType__c),              // 税コード   
                                DetailDFF1__c = obj.Record.InvoiceDisplayName__c,                           // 明細DFF1
                                DetailDFF2__c = obj.Record.Product2Detail__c,                               // 明細DFF2
                                DetailProject__c = obj.Record.ProjectCode__c,                               // 明細_プロジェクト
                                // DetailAccountingDepartment__c = obj.Record.AccountingDepartment__c,         // 明細_計上部門
                                DetailAccount__c = obj.Record.AccountCode__c,                               // 明細_勘定科目
                                // DetailProduct__c = obj.Record.ProductCode2__c,                              // 明細_商品
                                RecordingMethod__c = obj.Record.RecordingMethod__c,                         // 計上方法
                                RecordingMonth__c = obj.Record.RecordingMonth__c,                           // 計上年月
                                ContinuationMonth__c = obj.Record.ContinuationMonth__c,                     // 按分回数
                                Unit__c = obj.Record.Unit__c,                                               // 単位
                                // DetailDescription__c = obj.Record.AccountName__c,                           // 明細摘要
                                //Charge__c = employeeNumber,                                                 // 担当者
                                DetailProduct__c = obj.Record.ProductCode2__c,                              //明細_商品
                                DetailDFF3__c = obj.Record.Product2Detail3__c,                              //明細DFF3
                                DetailDFF4__c = obj.Record.Product2Detail4__c,                              //明細DFF4
                                DetailDFF5__c = obj.Record.Product2Detail5__c,                              //明細DFF5
                                DetailDFF6__c = obj.Record.Product2Detail6__c,                              //明細DFF6
                                DetailDFF7__c = obj.Record.Product2Detail7__c,                              //明細DFF7
                                DetailAccountingDepartment__c = obj.Record.AccountingDepartment__c,         //明細_計上部門
                                DetailProductDisplay__c = (String)obj.Record.get('ProductCode2Label'),      //明細_商品（表示）
                                DetailAccountingDepartmentForDisplay__c = (String)obj.Record.get('AccountingDepartmentLabel')   //明細_計上部門（表示）
                            ),
                            obj.Record.Product2Id__r.Name,
                            obj.Record.Product2Detail__c,
                            obj.Record.RecordingMonth__c,
                            obj.Record.RecordingPriceTotal__c,
                            // invoiceHeaderObjectMaster.size() + 1
                            String.ValueOf(getNextRecordNumber(invoiceHeaderObjectMaster)),
                            tmpBillingInformation.Name,
                            obj.Record.InvoiceDisplayName__c,
                            tmpBillingInformation.CustomerName__c

                        )
                    );
                }
            // 選択されていない場合
            } else {
                // Mapから削除
                mapSalesLineItemSelectedId.remove(obj.record.Id);
            }
            
        }

        invoiceDetailObjectMaster = setRowSpan(invoiceDetailObjectMaster, 'master');

        if(selectedFlg){

            // 請求先を取得
            BillingInformation__c billingInfo = getBillingInformation(item.BillingOffice__c);
            // 請求書ヘッダを作成
            String InvoiceDeliveryEmailAddressCC = '';
            String InvoiceDeliveryEmailAddressTo = '';
            Boolean InternalTransactionCheck = false;
            if(billingInfo.AccountType__c == '90'){
                //請求先.アカウントタイプが「内部取引先」の場合、請求書情報.内部取引チェックをtrueに設定
                InternalTransactionCheck = true;
            } else {
                //請求先.アカウントタイプが「内部取引先」以外の場合、請求書情報.請求書_送付先メールアドレス項目を設定
                InvoiceDeliveryEmailAddressCC = billingInfo.InvoiceDeliveryEmailAddressCC__c;
                InvoiceDeliveryEmailAddressTo = billingInfo.InvoiceDeliveryEmailAddressTo__c;
            }

            invoiceHeaderObjectMaster.add(
                new invoiceHeaderObjectWrapper(
                    new InvoiceHeader__c(
                        Opportunity__c = System.currentPageReference().getParameters().get('ID'),           //商談ID
                        BillingOffice__c = item.BillingOffice__c,                                           //請求先事業所
                        // PaymentTerms__c =  billingInfo.PaymentTerms__c,                                     //支払条件
                        // PrintOption__c = billingInfo.PrintOption__c,                                     //印刷オプション
                        InvoiceCorporationName__c = billingInfo.InvoiceCorporationName__c,                  //法人名称
                        IssueVoucherDepartment__c = loginUser.Department__c,                                //ログインユーザの部門
                        IssueVoucherPersonReference__c = UserInfo.getUserId(),                              //ログインユーザID
                        TransactionSubject__c = System.currentPageReference().getParameters().get('name'),   //取引件名

                        /**以下請求先の項目値をコピー */
                        PaymentTerms__c = billingInfo.PaymentTerms__c,                                      //支払条件
                        PaymentTermsForDisplay__c = (String)billingInfo.get('PaymentTermsLabel'),           //支払条件（表示）
                        BillToAccountNo__c = billingInfo.ProactiveCode__c,                                  //請求先アカウント番号
                        InvoiceUnitManagerName__c = billingInfo.UnitManagerName__c,                         //請求書_日経ユニット長名
                        InvoiceAddressRow1__c = billingInfo.Address1__c,                                    //請求書_住所行1
                        InvoiceAddressRow2__c = billingInfo.Address2__c,                                    //請求書_住所行2
                        InvoiceAddressRow3__c = billingInfo.Address3__c,                                    //請求書_住所行3
                        InvoicePostalCode__c = billingInfo.PostalCode__c,                                   //請求書_郵便番号
                        InvoiceHonorificTitle__c = billingInfo.InvoiceHonorificTitle__c,                    //請求書_敬称
                        InvoiceCharge__c = billingInfo.InvoiceCharge__c,                                    //請求書_担当者
                        InvoiceDepartmentName__c = billingInfo.InvoiceDepartmentName__c,                    //請求書_部署名
                        BillToSiteNo__c = billingInfo.SiteNo__c,                                            //請求先サイト番号
                        InvoiceSendMethod__c = billingInfo.InvoiceSendMethod__c,                            //請求書_送付方法
                        InternalTransactionCheck__c = InternalTransactionCheck,                             //内部取引チェック
                        InvoiceDeliveryEmailAddressCC__c = InvoiceDeliveryEmailAddressCC,                   //請求書_送付先メールアドレス（CC）
                        InvoiceDeliveryEmailAddressTo__c = InvoiceDeliveryEmailAddressTo                    //請求書_送付先メールアドレス（To）
                    ),

                    getNextRecordNumber(invoiceHeaderObjectMaster)
                )
            );
        }

        // マスタでループ
        for(salesLineItemObjectWrapper obj2 : salesLineItemObjectMaster){
            // Map内に該当レコードが存在する場合
            if(mapSalesLineItemSelectedId.get(obj2.record.Id) != null){
                // 選択済みにする
                obj2.selected = true;
            } 
            // 売上情報ロック処理 start
            // 存在しない場合
            // else {
            //     // 選択解除する
            //     obj2.selected = false;
            // }
            // 売上情報ロック処理 end
        }
    }
    // 保存ボタン(編集時)
    public void selectInvoiceSaveToEdit(){
        // 請求先情報取得
        BillingInformation__c tmpBillingInformation = getBillingInformation(item.BillingOffice__c);
        // Mapに格納
        billingInformationMap.put(tmpBillingInformation.Id,tmpBillingInformation);

        // 社員番号取得
        String employeeNumber = getOpportunity().Owner.EmployeeNumber__c;

        // 選択済みがあるかどうかの判定用
        Boolean selectedFlg = false;
        // ヘッダ番号退避
        Integer selectHeaderNumber = 0;
        // 売上情報ロック処理 start
        // この操作でチェックを付けた/外した商品IDを保持
        List<Id> selectedSalesLineItemIdList = new List<Id>();
        List<Id> unselectedSalesLineItemIdList = new List<Id>();
        // 売上情報ロック処理 end
        // マスタでループ
        for(salesLineItemObjectWrapper obj : salesLineItemObjectSelects){
            // 選択されている場合
            if(obj.selected){
                // 選択済み有フラグをTrueにする
                selectedFlg = true;

                // 請求明細に追加済みか判定する
                if(mapSalesLineItemSelectedId.get(obj.record.Id) != null){
                    // ヘッダとのリレーション（ヘッダ番号）を再設定する
                    for(invoiceDetailObjectWrapper obj2 : invoiceDetailObjectMaster){
                        if(obj.record.Id == obj2.record.SalesLineItem__c){
                            // 振り直しを行うヘッダ番号を退避
                            selectHeaderNumber = Integer.ValueOf(obj2.relationInvoiceHeaderNumber);
                            // 明細のヘッダ番号を再設定
                            obj2.relationInvoiceHeaderNumber = String.ValueOf(getNextRecordNumber(invoiceHeaderObjectMaster));
                            // 請求先（表示）を再設定
                            // obj2.BillingOffice = tmpBillingInformation.CustomerName__c;
                            obj2.BillingOffice = tmpBillingInformation.Name;
                            break;
                        }
                    }
                } else {
                    // 請求書明細に追加
                    invoiceDetailObjectMaster.add(
                        new invoiceDetailObjectWrapper(
                            new InvoiceDetail__c(
                                // 請求明細の値設定
                                // 請求ヘッダへの参照はInsert時に設定する（ここでは設定しない）
                                SalesLineItem__c = obj.Record.Id,                                           // 売上情報
                                Quantity__c = obj.Record.Quantity__c,                                       // 数量
                                UnitPrice__c = obj.Record.UnitPrice__c,                                     // 単価
                                TaxCode__c = getTaxCode(tmpBillingInformation.AccountType__c),              // 税コード   
                                DetailDFF1__c = obj.Record.InvoiceDisplayName__c,                           // 明細DFF1
                                DetailDFF2__c = obj.Record.Product2Detail__c,                               // 明細DFF2
                                DetailProject__c = obj.Record.ProjectCode__c,                               // 明細_プロジェクト
                                // DetailAccountingDepartment__c = obj.Record.AccountingDepartment__c,         // 明細_計上部門
                                DetailAccount__c = obj.Record.AccountCode__c,                               // 明細_勘定科目
                                // DetailProduct__c = obj.Record.ProductCode2__c,                              // 明細_商品
                                RecordingMethod__c = obj.Record.RecordingMethod__c,                         // 計上方法
                                RecordingMonth__c = obj.Record.RecordingMonth__c,                           // 計上年月
                                ContinuationMonth__c = obj.Record.ContinuationMonth__c,                     // 按分回数
                                Unit__c = obj.Record.Unit__c,                                               // 単位
                                // DetailDescription__c = obj.Record.AccountName__c,                           // 明細摘要
                                //Charge__c = employeeNumber,                                                 // 担当者
                                DetailProduct__c = obj.Record.ProductCode2__c,                              //明細_商品
                                DetailDFF3__c = obj.Record.Product2Detail3__c,                              //明細DFF3
                                DetailDFF4__c = obj.Record.Product2Detail4__c,                              //明細DFF4
                                DetailDFF5__c = obj.Record.Product2Detail5__c,                              //明細DFF5
                                DetailDFF6__c = obj.Record.Product2Detail6__c,                              //明細DFF6
                                DetailDFF7__c = obj.Record.Product2Detail7__c,                              //明細DFF7
                                DetailAccountingDepartment__c = obj.Record.AccountingDepartment__c,         //明細_計上部門
                                DetailProductDisplay__c = (String)obj.Record.get('ProductCode2Label'),      //明細_商品（表示）
                                DetailAccountingDepartmentForDisplay__c = (String)obj.Record.get('AccountingDepartmentLabel')   //明細_計上部門（表示）
                            ),
                            obj.Record.Product2Id__r.Name,
                            obj.Record.Product2Detail__c,
                            obj.Record.RecordingMonth__c,
                            obj.Record.RecordingPriceTotal__c,
                            String.ValueOf(getNextRecordNumber(invoiceHeaderObjectMaster)),
                            tmpBillingInformation.Name,
                            obj.Record.InvoiceDisplayName__c,
                            tmpBillingInformation.CustomerName__c
                        )
                    );
                    selectedSalesLineItemIdList.add(obj.Record.Id);
                }
                // Mapに追加
                mapSalesLineItemSelectedId.put(obj.record.Id,obj);

            // 選択されていない場合
            } else {
                // 請求明細に追加済みか判定する
                if(mapSalesLineItemSelectedId.get(obj.record.Id) != null){
                    //請求明細ラッパーリストから、削除するINDEXを抽出する
                    Integer deleteIndex = 0;
                    Integer i = 0;
                    // マスタから削除する
                    for(invoiceDetailObjectWrapper obj2 : invoiceDetailObjectMaster){

                        //売上情報のIDが一致したらリストから削除する
                        if(obj.record.Id == obj2.record.SalesLineItem__c){
                            deleteIndex = i;
                        }
                        i += 1;
                    }
                    invoiceDetailObjectMaster.remove(deleteIndex);
                    unselectedSalesLineItemIdList.add(obj.Record.Id);

                }
                // Mapから削除
                mapSalesLineItemSelectedId.remove(obj.record.Id);
            }
        }


        //ヘッダ情報更新
        for(invoiceHeaderObjectWrapper header : invoiceHeaderObjectMaster){
            if( header.recordNumber == selectHeaderNumber){
                // header.recordNumber = invoiceHeaderObjectMaster.size() + 1;
                header.recordNumber = getNextRecordNumber(invoiceHeaderObjectMaster);
                header.record.BillingOffice__c = tmpBillingInformation.Id;
            }
        }

        //明細が1件もないヘッダを削除
        //ループインデックス
        Integer loopIndex = 0;
        //削除対象のインデックス
        List<Integer> deleteIndexList = new List<Integer>();
        for(invoiceHeaderObjectWrapper header : invoiceHeaderObjectMaster){
            //明細をループ
            List<invoiceDetailObjectWrapper> detailExistCheck = new List<invoiceDetailObjectWrapper>();
            
            for(invoiceDetailObjectWrapper detail : invoiceDetailObjectMaster){
                if(header.recordNumber == Integer.valueOf(detail.relationInvoiceHeaderNumber)){
                    detailExistCheck.add(detail);
                    break;
                }
            }
            //明細が1件もない場合、削除リストにadd
            if(detailExistCheck.size() == 0) {
                deleteIndexList.add(loopIndex);
            }
            loopIndex++;
        }

        for(Integer index : deleteIndexList){
            invoiceHeaderObjectMaster.remove(index);
        }        

        //ヘッダ番号でソート
        invoiceDetailObjectMaster = invoiceDetailObjectWrapperSort(invoiceDetailObjectMaster);

        invoiceDetailObjectMaster = setRowSpan(invoiceDetailObjectMaster, 'master');
        
        // マスタでループ
        for(salesLineItemObjectWrapper obj2 : salesLineItemObjectMaster){
            // 売上情報ロック処理 start
            // Map内に該当レコードが存在する場合
            // if(mapSalesLineItemSelectedId.get(obj2.record.Id) != null){
            if(selectedSalesLineItemIdList.contains(obj2.record.Id)){
                // 選択済みにする
                obj2.selected = true;
            }

            if(unselectedSalesLineItemIdList.contains(obj2.record.Id)){
                // 選択解除する
                obj2.selected = false;
            }
            // 売上情報ロック処理 end
        }
    }
    // 保存ボタン（作成済み）
    public void selectInvoiceSaveToCreated(){

        // 請求ヘッダの請求先設定
        InvoiceHeader__c updateInvoiceHeader = new InvoiceHeader__c();
        updateInvoiceHeader = getInvoiceHeader(editClickRowHeaderId);
        updateInvoiceHeader.BillingOffice__c = item.BillingOffice__c;

        // 請求ヘッダ更新用Mapへの格納
        updateInvoiceHeaderMap.put(editClickRowHeaderId,updateInvoiceHeader);

        // 請求先情報取得
        BillingInformation__c tmpBillingInformation = getBillingInformation(item.BillingOffice__c);
        // Mapに格納
        billingInformationMap.put(tmpBillingInformation.Id,tmpBillingInformation);

        // 社員番号取得
        String employeeNumber = getOpportunity().Owner.EmployeeNumber__c;

        // 選択済みがあるかどうかの判定用
        Boolean selectedFlg = false;
        // ヘッダ番号退避
        Integer selectHeaderNumber = 0;

        // 売上情報ロック処理 start
        // この操作でチェックを付けた/外した商品IDを保持
        List<Id> selectedSalesLineItemIdList = new List<Id>();
        List<Id> unselectedSalesLineItemIdList = new List<Id>();
        // 売上情報ロック処理 end

        // マスタでループ
        for(salesLineItemObjectWrapper obj : salesLineItemObjectSelects){
            // 選択されている場合
            if(obj.selected){
                // 選択済み有フラグをTrueにする
                selectedFlg = true;

                Boolean createdFlg = false;
                for(invoiceDetailObjectWrapper obj2 : invoiceDetailObjectCreated){
                    if(obj.record.Id == obj2.record.SalesLineItem__c &&
                        editClickRowHeaderId == obj2.record.InvoiceHeader__c){
                        // 同一ヘッダの作成済み明細にある場合
                        createdFlg = true;
                        // 請求先情報を更新する
                        if(obj2.record.Id != null){
                            obj2.record.InvoiceHeader__r.BillingOffice__c = item.BillingOffice__c;
                            obj2.BillingOffice = tmpBillingInformation.Name;
                        }
                        break;
                    }
                }
                if(!createdFlg){ 
                    // 作成済み明細にない場合
                    // 作成済み請求明細に追加する
                    invoiceDetailObjectCreated.add(
                        new invoiceDetailObjectWrapper(
                            new InvoiceDetail__c(
                                // 請求明細の値設定
                                InvoiceHeader__c = editClickRowHeaderId,                                    // 請求ヘッダ
                                SalesLineItem__c = obj.Record.Id,                                           // 売上情報
                                Quantity__c = obj.Record.Quantity__c,                                       // 数量
                                UnitPrice__c = obj.Record.UnitPrice__c,                                     // 単価
                                TaxCode__c = getTaxCode(tmpBillingInformation.AccountType__c),              // 税コード   
                                DetailDFF1__c = obj.Record.InvoiceDisplayName__c,                           // 明細DFF1
                                DetailDFF2__c = obj.Record.Product2Detail__c,                               // 明細DFF2
                                DetailProject__c = obj.Record.ProjectCode__c,                               // 明細_プロジェクト
                                // DetailAccountingDepartment__c = obj.Record.AccountingDepartment__c,         // 明細_計上部門
                                DetailAccount__c = obj.Record.AccountCode__c,                               // 明細_勘定科目
                                // DetailProduct__c = obj.Record.ProductCode2__c,                              // 明細_商品
                                RecordingMethod__c = obj.Record.RecordingMethod__c,                         // 計上方法
                                RecordingMonth__c = obj.Record.RecordingMonth__c,                           // 計上年月
                                ContinuationMonth__c = obj.Record.ContinuationMonth__c,                     // 按分回数
                                Unit__c = obj.Record.Unit__c,                                               // 単位
                                // DetailDescription__c = obj.Record.AccountName__c,                           // 明細摘要
                                //Charge__c = employeeNumber,                                                 // 担当者
                                DetailProduct__c = obj.Record.ProductCode2__c,                              //明細_商品
                                DetailDFF3__c = obj.Record.Product2Detail3__c,                              //明細DFF3
                                DetailDFF4__c = obj.Record.Product2Detail4__c,                              //明細DFF4
                                DetailDFF5__c = obj.Record.Product2Detail5__c,                              //明細DFF5
                                DetailDFF6__c = obj.Record.Product2Detail6__c,                              //明細DFF6
                                DetailDFF7__c = obj.Record.Product2Detail7__c,                              //明細DFF7
                                DetailAccountingDepartment__c = obj.Record.AccountingDepartment__c,         //明細_計上部門
                                DetailProductDisplay__c = (String)obj.Record.get('ProductCode2Label'),      //明細_商品（表示）
                                DetailAccountingDepartmentForDisplay__c = (String)obj.Record.get('AccountingDepartmentLabel')   //明細_計上部門（表示）
                            ),
                            obj.Record.Product2Id__r.Name,
                            obj.Record.Product2Detail__c,
                            obj.Record.RecordingMonth__c,
                            obj.Record.RecordingPriceTotal__c,
                            editClickRowHeaderName,
                            tmpBillingInformation.Name,
                            obj.Record.InvoiceDisplayName__c,
                            tmpBillingInformation.CustomerName__c
                        )
                    );
                }

                // Mapに追加
                mapSalesLineItemSelectedId.put(obj.record.Id,obj);
                selectedSalesLineItemIdList.add(obj.Record.Id);

            // 選択されていない場合
            } else {
                Boolean createdFlg = false;
                Integer deleteIndex = 0;
                for(invoiceDetailObjectWrapper obj2 : invoiceDetailObjectCreated){
                    if(obj.record.Id == obj2.record.SalesLineItem__c && obj2.record.InvoiceHeader__c == editClickRowHeaderId){
                        // 作成済み明細にある場合

                        createdFlg = true;
                        // 作成済み請求明細から削除する行を退避する
                        unselectedInvoiceDetailList.add(obj2.record);

                        //レコードとして既に作成されている場合、削除対象とする
                        if(obj2.record.Id != null) deleteInvoiceDetailList.add(obj2.record);
                        break;
                    }
                    deleteIndex += 1;
                }
                if(createdFlg){
                    // 作成済み請求明細から削除する
                    invoiceDetailObjectCreated.remove(deleteIndex);
                    unselectedSalesLineItemIdList.add(obj.Record.Id);
                } 
                // Mapから削除
                mapSalesLineItemSelectedId.remove(obj.record.Id);
            }
        }
        //ヘッダ番号でソート
        invoiceDetailObjectCreated = invoiceDetailObjectWrapperSort(invoiceDetailObjectCreated);

        invoiceDetailObjectCreated = setRowSpan(invoiceDetailObjectCreated, 'created');

        // 売上情報ロック処理 start
        // マスタでループ
        for(salesLineItemObjectWrapper obj2 : salesLineItemObjectMaster){
            // 新しく選択した商品
            if(selectedSalesLineItemIdList.contains(obj2.record.Id)){
                // 選択済みにする
                obj2.selected = true;
            }
            // 新しく選択を外した商品
            if(unselectedSalesLineItemIdList.contains(obj2.record.Id)){
                // 選択解除する
                obj2.selected = false;
            }
        }
        // 売上情報ロック処理 end
    }
    // 請求書情報・明細編集（フロー起動）
    public PageReference clickFlowOpen(){
        // フローの相対URLを定義
        String flowURL = '/flow/InvoiceHeaderUpdate';

        // 選択した行番号を取得
        rowNumberCreated = Integer.ValueOf(System.currentPageReference().getParameters().get('numberCreated'));
        // 選択した行の請求書情報IDを取得
        String invoiceHeaderId = invoiceDetailObjectCreated.get(rowNumberCreated).record.InvoiceHeader__c;
        // フロー完了後に商談ページに遷移するretURLパラメータを連結
        flowURL += '?retURL=';
        flowURL += productId;
        // フローURLに請求書情報IDを連結
        flowURL += '&id=';
        flowURL += invoiceHeaderId;
        // PageReferenceの生成
        PageReference p = new PageReference(flowURL);

        return p;
    }
    // 商品追加リンク（作成済み）
    public void editCreatedInvoice(){
        System.debug('rowNumberCreated：' + Integer.ValueOf(System.currentPageReference().getParameters().get('numberCreated')));
        // 選択した行番号を取得
        rowNumberCreated = Integer.ValueOf(System.currentPageReference().getParameters().get('numberCreated'));
        // 選択した行の請求明細を取得
        invoiceDetailObjectWrapper clickInvoiceDetail = invoiceDetailObjectCreated.get(rowNumberCreated);
        // 選択した行のヘッダIDとNameを保存
        editClickRowHeaderId = clickInvoiceDetail.record.InvoiceHeader__c;
        editClickRowHeaderName = clickInvoiceDetail.record.InvoiceHeader__r.Name;

        // 請求先を設定
        item = getInvoiceHeader(clickInvoiceDetail.record.InvoiceHeader__c);
        item.BillingOffice__c = getInvoiceHeader(clickInvoiceDetail.record.InvoiceHeader__c).BillingOffice__c;

        // 選択した請求明細と同じ請求ヘッダを持つ請求明細を取得
        List<invoiceDetailObjectWrapper> clickInvoiceDetailGroup = new List<invoiceDetailObjectWrapper>();
        for(invoiceDetailObjectWrapper obj : invoiceDetailObjectCreated){
            if(obj.record.InvoiceHeader__c == clickInvoiceDetail.record.InvoiceHeader__c){
                clickInvoiceDetailGroup.add(obj);
            }
        }
      
        List<salesLineItemObjectWrapper> selectedSalesLineItemList = new List<salesLineItemObjectWrapper>();
        for(salesLineItemObjectWrapper master: salesLineItemObjectMaster){
            // 選択状態の初期化
            // master.selected = false;

            // 選択した請求書に対応する商品の場合は選択済みで表示
            for(invoiceDetailObjectWrapper selected: clickInvoiceDetailGroup){
                if(master.record.Id == selected.record.SalesLineItem__c){
                    master.selected = true;
                    selectedSalesLineItemList.add(master);
                    continue;
                }
            }
            
        }
        salesLineItemObjectSelects = selectedSalesLineItemList;

        for(salesLineItemObjectWrapper obj : salesLineItemObjectMaster){
            // 未選択かつ未ロックの商品は未選択状態で表示
            // if(!obj.selected && !obj.Record.IsLocked__c){
            if(!obj.selected){
                // obj.selected = false;
                salesLineItemObjectSelects.add(obj);
            }
        }
        // 売上情報ロック処理 end

        //画面表示時点の売上情報の選択状態を保持 ※戻るボタン押下時にその状態に戻すため
        SalesLineItemBackUpList = salesLineItemObjectSelects.clone();

        //backup用のチェックボックス変数に選択状態の値を格納
        for( salesLineItemObjectWrapper obj : SalesLineItemBackUpList){
            obj.backupSelected = obj.selected;
            System.debug('コピー売上情報:' + obj.record.InvoiceDisplayName__c + ' ' + obj.backupSelected);
        }
    }
    // 商品追加リンク（未作成）
    public void editSelectInvoice(){

        // 選択した行番号を取得
        rowNumberSelect = Integer.ValueOf(System.currentPageReference().getParameters().get('numberSelect'));
        // 選択した行の請求明細を取得
        invoiceDetailObjectWrapper clickInvoiceDetail = invoiceDetailObjectMaster.get(rowNumberSelect);
        // 選択した請求明細と同じ請求ヘッダを持つ請求明細を取得
        List<invoiceDetailObjectWrapper> clickInvoiceDetailGroup = new List<invoiceDetailObjectWrapper>();
        for(invoiceDetailObjectWrapper obj : invoiceDetailObjectMaster){
            if(obj.relationInvoiceHeaderNumber == clickInvoiceDetail.relationInvoiceHeaderNumber){
                clickInvoiceDetailGroup.add(obj);
            }
        }

        // 選択された請求明細から、売上一覧に表示するためのリストを作成
        List<salesLineItemObjectWrapper> selectedSalesLineItemList = new List<salesLineItemObjectWrapper>();
        for(salesLineItemObjectWrapper master: salesLineItemObjectMaster){
            for(invoiceDetailObjectWrapper selected: clickInvoiceDetailGroup){
                if(master.record.Id == selected.record.SalesLineItem__c){
                    selectedSalesLineItemList.add(master);
                }
            }
        }
        salesLineItemObjectSelects = selectedSalesLineItemList;

        for(salesLineItemObjectWrapper obj : salesLineItemObjectMaster){
            if(!obj.selected){
                salesLineItemObjectSelects.add(obj);
            }
        }

        //画面表示時点の売上情報の選択状態を保持 ※戻るボタン押下時にその状態に戻すため
        SalesLineItemBackUpList = salesLineItemObjectSelects.clone();

        //backup用のチェックボックス変数に選択状態の値を格納
        for( salesLineItemObjectWrapper obj : SalesLineItemBackUpList){
            obj.backupSelected = obj.selected;
            System.debug('コピー売上情報:' + obj.record.InvoiceDisplayName__c + ' ' + obj.backupSelected);
        }
    }

    //戻るボタン押下時の処理：売上情報の選択状態を元の状態にもどす
    public void backToInvoiceListTable(){
        
        //一覧に表示する売上情報リストを画面表示時点の売上情報リストに上書き
        salesLineItemObjectSelects = SalesLineItemBackUpList;
        for( salesLineItemObjectWrapper obj : salesLineItemObjectSelects){
            //画面表示時点の選択状態に戻す
            obj.selected = obj.backupSelected;
        }
    }


    // 新規請求書作成ボタン
    // 作成済み請求明細更新ボタン
    // (どちらも共通の処理)
    // (請求情報・明細作成処理)
    public void saveInvoice(){
        //以下、既存ヘッダ分
        update updateInvoiceHeaderMap.values();
        //以下、既存明細分
        List<InvoiceDetail__c> insertInvoiceDetailCreatedList = new List<InvoiceDetail__c>();
        List<InvoiceDetail__c> updateInvoiceDetailCreatedList = new List<InvoiceDetail__c>();
        // 表示順設定処理 start
        // Map<参照番号, 既存の最大の表示順>のMap
        Map<String, Integer> maxDisplayOrderMap = new Map<String, Integer>();
        // ヘッダの最大の明細枝番(明細.Name設定用)･･･Map<ヘッダのName,明細枝番の最大値>
        Map<String,Integer> maxDetailBranchNumber = new Map<String,Integer>();
        List<invoiceDetailObjectWrapper> insertInvoiceDetailObjectList = new List<invoiceDetailObjectWrapper>();
        // 表示順設定処理 end
        for(invoiceDetailObjectWrapper obj: invoiceDetailObjectCreated){
            if(obj.record.Id == null){
                //Name設定処理 start
                system.debug(obj.Record.InvoiceHeader__r.Name);
                // ヘッダのNameを取得
                String headerName = getInvoiceHeader(obj.Record.InvoiceHeader__c).Name;
                // 明細枝番の最大値を取得
                Integer branchNumber = maxDetailBranchNumber.get(headerName);
                if (branchNumber == null) {
                    branchNumber = 0;
                }
                // 明細枝番+1
                branchNumber += 1;
                // 明細のNameを設定（ヘッダのName + '-' + 明細枝番の2桁0埋め）
                obj.Record.Name = headerName + '-' + String.ValueOf(branchNumber).leftPad(2,'0');
                // ヘッダの枝番最大値を更新
                maxDetailBranchNumber.put(headerName,branchNumber);
                insertInvoiceDetailObjectList.add(obj);
                //Name設定処理 end
            } else {

                // 表示順設定処理 start
                // 各参照番号の表示順の最大値を保持
                if (obj.relationInvoiceHeaderNumber!=null && obj.Record.DisplayOrderNo__c!=null) {
                    Integer previousDisplayOrder = (Integer) maxDisplayOrderMap.get(obj.relationInvoiceHeaderNumber);
                    if (previousDisplayOrder == null || obj.Record.DisplayOrderNo__c > previousDisplayOrder) {
                        maxDisplayOrderMap.put(obj.relationInvoiceHeaderNumber, obj.Record.DisplayOrderNo__c.intValue());
                    }
                }
                
                // 表示順設定処理 end

                // Name設定処理 start
                if(maxDetailBranchNumber.get(obj.Record.InvoiceHeader__r.Name) == null || 
                   maxDetailBranchNumber.get(obj.Record.InvoiceHeader__r.Name) < Integer.ValueOf(obj.Record.Name.Right(2))){
                    system.debug('obj.Record.Name.Right(2)：'+obj.Record.Name.Right(2));
                    maxDetailBranchNumber.put(obj.Record.InvoiceHeader__r.Name,Integer.ValueOf(obj.Record.Name.Right(2)));
                }
                // Name設定処理 end

            }            
        }

        // 表示順設定処理 start
        // レコードをソート ※relationInvoiceHeaderNumberを基準にソートされる
        insertInvoiceDetailObjectList.sort();
        Integer displayOrderNo = 10;
        String previousHeaderName = '';
        for (invoiceDetailObjectWrapper obj: insertInvoiceDetailObjectList) {
            if (obj.relationInvoiceHeaderNumber==previousHeaderName) {
                // ひとつ前のレコードと参照番号(請求書ヘッダ.Name)が同じなら+10した表示順
                displayOrderNo += 10;
            }else if (maxDisplayOrderMap.get(obj.relationInvoiceHeaderNumber)!=null) {
                // 既存に同参照番号が存在するならその最大値+10
                displayOrderNo = (Integer) maxDisplayOrderMap.get(obj.relationInvoiceHeaderNumber) + 10;
            }else {
                // 既存に存在しないなら初期値10
                displayOrderNo = 10;
            }
            previousHeaderName = obj.relationInvoiceHeaderNumber;
            obj.Record.DisplayOrderNo__c = displayOrderNo;
            insertInvoiceDetailCreatedList.add(obj.record);
        }
        // 表示順設定処理 end

        insert insertInvoiceDetailCreatedList;

       delete deleteInvoiceDetailList;

        //以下、新規明細・ヘッダ分
        //参照番号用連番の定義
        Integer nameNumber = 1;
        //参照番号用日時の定義
        String nowDatetime = datetime.now().format('yyyyMMddHHmmssSSS', UserInfo.getTimeZone().getId());
        //トランザクション日の初期値取得 最小の請求書明細.会計日をデフォルト値に設定
        Date defaultTransactionDate;
        for(invoiceDetailObjectWrapper obj: invoiceDetailObjectMaster){
            if(defaultTransactionDate == null){
                defaultTransactionDate = obj.Record.RecordingMonth__c;
            } else if(defaultTransactionDate > obj.Record.RecordingMonth__c){
                defaultTransactionDate = obj.Record.RecordingMonth__c;
            }
        }

        // 請求ヘッダラッパーのレコードを登録する
        List<InvoiceHeader__c> insertInvoiceHeaderList = new List<InvoiceHeader__c>();
        
        for(invoiceHeaderObjectWrapper obj: invoiceHeaderObjectMaster){
            //トランザクション日を設定
            obj.record.TransactionDate__c = defaultTransactionDate;

            //現在日時 + ログインユーザの社員番号下5桁 + 連番
            obj.record.Name = nowDatetime + loginUser.EmployeeNumber__c.right(5) + String.Valueof(nameNumber).leftPad(3,'0');

            //連番を+            
            nameNumber += 1;

            insertInvoiceHeaderList.add(obj.record);
        }

        insert insertInvoiceHeaderList;

        Map<Integer,InvoiceHeader__c> invoiceHeaderNumberMap = new Map<Integer,InvoiceHeader__c>();
        for(invoiceHeaderObjectWrapper headerWrapper: invoiceHeaderObjectMaster){
            invoiceHeaderNumberMap.put(headerWrapper.recordNumber,headerWrapper.record);
        }

        // 請求明細ラッパーのレコードを登録する
        List<InvoiceDetail__c> insertInvoiceDetailList = new List<InvoiceDetail__c>();
        String headerId = ''; 
        Integer recordNameBranchNumber = 0;
        
        for(invoiceDetailObjectWrapper obj: invoiceDetailObjectMaster){
            if(headerId <> String.ValueOf(invoiceHeaderNumberMap.get(Integer.ValueOf(obj.relationInvoiceHeaderNumber)).Id)){
                headerId = String.ValueOf(invoiceHeaderNumberMap.get(Integer.ValueOf(obj.relationInvoiceHeaderNumber)).Id);
                recordNameBranchNumber = 1;
            } else {
                recordNameBranchNumber += 1;
            }
            
			obj.record.InvoiceHeader__c = invoiceHeaderNumberMap.get(Integer.ValueOf(obj.relationInvoiceHeaderNumber)).Id;
            obj.record.Name = invoiceHeaderNumberMap.get(Integer.ValueOf(obj.relationInvoiceHeaderNumber)).Name + '-' + String.ValueOf(recordNameBranchNumber).leftPad(2,'0');
        }

        // 表示順設定処理 start
        // レコードをソート
        invoiceDetailObjectMaster.sort();
        Integer displayOrderNoMaster = 10;
        String previousHeaderNumber = '';
        for(invoiceDetailObjectWrapper obj: invoiceDetailObjectMaster){
            if (obj.relationInvoiceHeaderNumber==previousHeaderNumber) {
                // ひとつ前のレコードと参照番号(請求書ヘッダ.Name)が同じなら+10した表示順
                displayOrderNoMaster += 10;
            }else {
                // 異なるなら初期値10
                displayOrderNoMaster = 10;
            }
            previousHeaderNumber = obj.relationInvoiceHeaderNumber;
            obj.Record.DisplayOrderNo__c = displayOrderNoMaster;
            insertInvoiceDetailList.add(obj.record);
        }
        // 表示順設定処理 end

        insert insertInvoiceDetailList;

        
        // 売上情報ロック処理 start
        Map<Id, SalesLineItem__c> updateSalesLineMap = new Map<Id, SalesLineItem__c>();
        // 既存請求書情報から削除した明細に紐付く売上情報のロックをfalseにする
        for (InvoiceDetail__c invcDetail : unselectedInvoiceDetailList) {
            updateSalesLineMap.put(invcDetail.SalesLineItem__c, new SalesLineItem__c(Id = invcDetail.SalesLineItem__c, IsLocked__c = false));
        }
        // 既存請求書情報に新規作成した明細に紐付く売上情報のロックをtrueにする
        for (InvoiceDetail__c invcDetail : insertInvoiceDetailCreatedList) {
            updateSalesLineMap.put(invcDetail.SalesLineItem__c, new SalesLineItem__c(Id = invcDetail.SalesLineItem__c, IsLocked__c = true));
        }
        // 新規請求書情報の明細に紐付く売上情報のロックをtrueにする
        for (InvoiceDetail__c invcDetail : insertInvoiceDetailList) {
            updateSalesLineMap.put(invcDetail.SalesLineItem__c, new SalesLineItem__c(Id = invcDetail.SalesLineItem__c, IsLocked__c = true));
        }
        update updateSalesLineMap.values();
        // 売上情報ロック処理 end
    }

    

    //ソート用クラス
    private List<invoiceDetailObjectWrapper> invoiceDetailObjectWrapperSort(List<invoiceDetailObjectWrapper> detailList){

        for (Integer s = 0; s < detailList.size() - 1; s++) {
            // s番目以降の最小値がどこにあるか探す
            Integer pos = s; // 最小値の場所（とりあえずs番目を最小とみなす）
            for (Integer i = s + 1; i < detailList.size(); i++) {
                if (detailList.get(i).relationInvoiceHeaderNumber < detailList.get(pos).relationInvoiceHeaderNumber) {
                    pos = i;
                }
            }
 
            // s番目とpos番目を交換する
            invoiceDetailObjectWrapper w = detailList.get(s);
            detailList.set(s,detailList.get(pos));
            detailList.set(pos,w);
        }
        return detailList;
    }

    // ヘッダ
    private Integer getNextRecordNumber (List<invoiceHeaderObjectWrapper> wrapperList ){
        Integer maxRecordNumber = 0;

        for(invoiceHeaderObjectWrapper wapper : wrapperList){
            if(maxRecordNumber < wapper.recordNumber){
                maxRecordNumber = wapper.recordNumber;
            }
        }
        maxRecordNumber += 1;

        return maxRecordNumber;

    }

    // 請求先取得
    private BillingInformation__c getBillingInformation(Id billingOfficeId){
        
        BillingInformation__c tmpBillingInformation = [
            SELECT
                Id,
                Name,
                LBC__c,                     //LBC
                AccountType__c,             //アカウント・タイプ
                CustomerName__c,            //顧客名
                InvoiceCorporationName__c,  //請求書_法人名称
                ProactiveCode__c,           //プロアクティブコード
                SiteNo__c,                  //サイト番号
                PaymentTerms__c,            //支払条件
                tolabel(PaymentTerms__c) PaymentTermsLabel,     //支払条件（ラベル値）
                InvoiceDeliveryEmailAddressCC__c,               //請求書_送付先メールアドレス（CC）
                InvoiceDeliveryEmailAddressTo__c,               //請求書_送付先メールアドレス（TO）
                UnitManagerName__c,         //日経ユニット長名
                Address1__c,                //住所1
                Address2__c,                //住所2
                Address3__c,                //住所3
                PostalCode__c,              //郵便番号
                InvoiceHonorificTitle__c,   //請求書_敬称
                InvoiceCharge__c,           //請求書_担当者
                InvoiceDepartmentName__c,   //請求書_部署名
                tolabel(InvoiceSendMethod__c)                   //請求書_送付方法（ラベル値）
            FROM
                BillingInformation__c
            WHERE
                Id = :billingOfficeId
        ];

        return tmpBillingInformation;
    }
    /**
     * テーブルの上下の参照番号が一致する場合の列結合処理
     * @param List<invoiceDetailObjectWrapper> objList テーブルに表示するラッパークラスのリスト
     * @param String targetTable どちらの表かの判定 created(作成済み)もしくはmaster(作成中)
     * @return rowSpanとrenderedを設定したラッパークラスのリスト
     */
    private List<invoiceDetailObjectWrapper> setRowSpan(List<invoiceDetailObjectWrapper> objList, String targetTable){
        List<invoiceDetailObjectWrapper> returnList = new List<invoiceDetailObjectWrapper>();
        for (Integer i = 0; i < objList.size() ; i++) {
            invoiceDetailObjectWrapper obj = objList[i];
            InvoiceDetail__c record = obj.Record;

            Integer rowSpanCount = 1;
            if (i!=0 && obj.getHeaderName(targetTable) == objList[i-1].getHeaderName(targetTable)) {
                // 上の行と一致する場合非表示
                rowSpanCount = 0;
            } else if (i!=objList.size()) {
                for (Integer j = i+1; j < objList.size(); j++) {
                    // 下の行と一致する場合、一致する行の数だけ跨ぐ列数を増やす
                    if ( obj.getHeaderName(targetTable)==objList[j].getHeaderName(targetTable)) {
                        rowSpanCount += 1;
                    } else {
                        continue;
                    }
                }
            }
            obj.setRowSpan(rowSpanCount);
            returnList.add(obj);
        }
        return returnList;
    }

    // 税コード判定
    private String getTaxCode(String accountType){
        // 請求明細に設定する税コードを判定
        String taxCode = '10EX';
        // 内部取引先(90)の場合、99を設定　それ以外は10EXを設定する
        if(accountType == '90'){
            taxCode = '99';
        }

        return taxCode;

    }
    // 商談取得
    private Opportunity getOpportunity(){
        Opportunity opp = [
            SELECT
                Id,
                Name,
                Owner.EmployeeNumber__c

            FROM
                Opportunity
            WHERE
                Id = :productId
        ];

        return opp;
    }

    // 請求書情報取得
    private InvoiceHeader__c getInvoiceHeader(Id headerId){
        InvoiceHeader__c header = [
            SELECT
                Id,
                Name,
                BillingOffice__c
                // BillingOffice__r.PrintOption__c
            FROM
                InvoiceHeader__c
            WHERE
                Id = :headerId
        ];

        return header;
    }

    //請求書作成後の戻るアクション
    public PageReference returnCreateInvoice(){
        PageReference pr = page.createinvoice;
        pr.getParameters().put('id', productId);
        pr.getParameters().put('name', productName);
        pr.setRedirect(true);
        return pr;
    }
    
}