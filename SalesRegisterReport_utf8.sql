
-- =======================================================
-- Author:		Anjum
-- Create date: 2013/05/30
-- Description:	Sales Register as Per Raj sales Requirement
-- =======================================================
-- Finance.SalesRegisterReport 4,'2015/04/01','2018/10/31',null,4,0
ALTER PROCEDURE [Finance].[SalesRegisterReport]
	-- Add the parameters for the stored procedure here
(
		 @CompanyNo int,
		 @FromDate smalldatetime,
		 @ToDate Smalldatetime,
		 @CustomerLocationNo int,
		 @InvoiceType smallint,
		 @TaxBookNo int,
		 @IsMisReport bit=1
	)
with recompile
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements. 
	SET NOCOUNT ON;

If	@InvoiceType=0 Set @InvoiceType=null
If	@CustomerLocationNo=0 Set @CustomerLocationNo=null
If	@TaxBookNo=0 Set @TaxBookNo=null

declare @IsGSTApplicable bit
select @IsGSTApplicable=IsGSTApplicable  from Finance.Setting where CompanyNo =@CompanyNo

If @IsMisReport=1
 Begin
  
  -- 0 Hidden Column Detail
        Select 0 as BandNo,'InvoiceNo' as [ColumnName] 
        union
        Select 0 as BandNo,'CompanyNo' as [ColumnName]
        union
        Select 0 as BandNo,'Type' as [ColumnName]
             union select 0,'BEDValue' where @IsGSTApplicable = 1		
             union select 0,'ExciseAmount' where @IsGSTApplicable = 1		
	union select 0,'SHEValue' where @IsGSTApplicable = 1
	union select 0,'EDUValue' where @IsGSTApplicable = 1
	union select 0,'VATCSTAmt' where @IsGSTApplicable = 1
	union select 0,'VATCSTRate' where @IsGSTApplicable = 1
	union select 0,'PartyTinNo' where @IsGSTApplicable = 1	
       
-- 1 Change Column Caption
	  Select 0 as BandNo,'CompanyName' PrevColumnName,'Company Name' NewColumnName

	  
	  
-- 2 Relation
	  Select 1 as RelationNo,0 as ParentTableNo,'ParentinvlotSummaryNo' as ParentColumnName,1 as ChildTableNo,'ParentinvlotSummaryNo' as ChildColumnName where 1=2
	
	  
-- 3 Lot Summary
    Select 1 As MergeSettingNo,'' as UniqueColumn,0 as BandNo,'' ApplyOnColumn where 1=2

End



--If	@TaxBookNo=0 Set @TaxBookNo=null
    -- Insert statements for procedure here
------------------------------------------------------------------------------------------------------------------
If OBJECT_ID('tempdb..#TempSRComp') is not NULL
	Drop Table #TempSRComp

Create table #TempSRComp (CompanyNo tinyint)

	if exists(select CompanyNo from masterdata.mCompanyMaster where HeadOfficeNO=@CompanyNO  )
	  Insert into #TempSRComp (CompanyNo) select CompanyNO from masterdata.mCOmpanyMaster where HeadOfficeNO =  @CompanyNo  
	else
	  Insert into #TempSRComp (CompanyNo)values (@CompanyNo) 

create nonclustered index Ix_TempSRComp on #TempSRComp(CompanyNo)	
----------------------------------------------------------------------------------------------------------------   
----Tax Book Handling

Create Table #TaxBook (TaxBookNo Smallint)
Insert Into #TaxBook (TaxBookNo)
Select isnull(TD.TransactionTaxBookNo,TB.TaxBookNo) TransactionTaxBookNo 
From masterdata.mTaxBookMain TB --- alll 
Left JOin masterdata.mTaxBookDetail TD on TD.TaxBookNo=TB.TaxBookNo --- Main (1. TD Main , 2. TB Transaction)
Inner Join  masterdata.mTaxBookCategoryDetail TC on TC.TaxBookNo=IsNull(TD.TransactionTaxBookNo,TB.TaxBookNo) and TC.TaxCategoryNo In (3,4,7,14)
Where TB.TaxBookNo=Isnull(@TaxBookNo,TB.TaxBookNo)
Group By isnull(TD.TransactionTaxBookNo,TB.TaxBookNo)

create nonclustered index Ix_TempTaxBook on #TaxBook(TaxBookNo)
------------------------------------------------------------------------------------------------------------------ 
Select [Type]
		,InvoiceNo
		,CompanyNo
		,CompanyName
		,DocumentNoYearly
		,DocumentDate
		,VoucherNo 
		,VoucherDate 
		,InvoiceType
		,[Invoice Month]  
		,[Invoice Category] 
		,SalesCategory
		,[Source Document]
		,[RefNo/Date]
		,[Party Name] 
		,FullAddress
		,StateName [State]
		,GSTStateCode [GST State Code]
		,GSTRegistrationType [GST Registration Type]
		,GSTINNo [Party GSTIN No]
		,[GSTR Section]
		,PartyTinNo
		,IRN
		,AckNo 
		,AckDate 
		,WayBillNo [EWay Bill No]
		,WayBillDate [EWay Bill Date]                            
		,LRNo
		,LRDate
		,ItemDescription
		,Unit
		,[Group Name]
		,[Material Type]
		,HSNSACCode
		,Quantity
        ,Rate
		,Convert(decimal(18,2),[Exchange Rate] * BasicAmt) BasicAmt
		,PCKFWDRate [Packing & Forwarding Rate]
		,Convert(decimal(18,2),[Exchange Rate] * PCKFWDValue) [Packing & Forwarding Value]
		,CGSTRate
		,Convert(decimal(18,2),[Exchange Rate] * CGSTValue) CGSTValue
		,SGSTRate
		,Convert(decimal(18,2),[Exchange Rate] * SGSTValue) SGSTValue
		,IGSTRate
		,Convert(decimal(18,2),[Exchange Rate] * IGSTValue) IGSTValue
		,UGSTRate
		,Convert(decimal(18,2),[Exchange Rate] * UGSTValue) UGSTValue
		,Convert(decimal(18,2),[Exchange Rate] * GSTCessValue) GSTCessValue
		,Convert(decimal(18,2),[Exchange Rate] * TCSValue) TCSValue
		,Convert(decimal(18,2),[Exchange Rate] * TransitInsuranceValue) [Insurance]
        ,Convert(decimal(18,2),[Exchange Rate] * OtherCharges) OtherCharges
		,Convert(decimal(18,2),[Exchange Rate] * NetAmount) NetAmount	
		,[Freight Type]
        ,StockAcc
        ,VendorInvoiceNo
		,ExciseAmount
        ,VATCSTRate
        ,VATCSTAmt        
        ,BEDValue
        ,SHEValue
        ,EDUValue
        ,@IsGSTApplicable IsGSTApplicable
		,IsCreateDC [Create DC Against This Inv.] 
		,[Freight Invoice No.]
		,[Freight Invoice Date]
		,FreightPayableAmount [Freight Amount]
From
(
    Select 1 as [Type]
		,SI.InvoiceNo
		,SI.CompanyNo
		,CM.CompanyName
		,SI.DocumentNoYearly
		,SI.DocumentDate
		,VM.DocumentNoYearly as VoucherNo
		,VM.DocumentDate as VoucherDate
		,'Tax Invoice' as InvoiceType
		,'Tax Invoice' as SalesCategory
		,isnull(Stuff((Select distinct ','+ '[' +convert(varchar,AM.DocumentNoYearly) +']' 
					 + '['+convert(varchar(50),AM.DocumentDate,103) +']'
				 From Sales.SalesOrderAmendmentMain AM 
				 Inner Join Sales.InvoiceItemDetails ID on ID.SalesOrderAmendmentNo=AM.SalesOrderAmendmentNo
				  where id.InvoiceNo=si.invoiceno 
				 -- order by AM.DocumentDate,AM.DocumentNoYearly 
				  for XML path('') ),1,1,''),SI.RefNoDate) as [RefNo/Date]
		,VL.VendorName [Party Name] 
		,VL.FullAddress		
		,VLI.TINNo as PartyTinNo 
		,VL.GSTINNo
		,ST.StateName
		,ST.GSTStateCode
		,RT.RegistrationType [GSTRegistrationType]
		,Stuff((Select ','+ HS.HSNSACCode
				 From Sales.InvoiceItemDetails ID				 
				 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
				 Inner Join Globaldata.HSNSACCode HS on HS.HSNSACCodeNo=IM.HSNSACCodeNo
				 where id.InvoiceNo=SI.InvoiceNo 
				 Group by HS.HSNSACCode
				  for XML path('') ),1,1,'') HSNSACCode
		,Stuff((Select ','+ IM.ItemDescription
				 From Sales.InvoiceItemDetails ID
				 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
				  where id.InvoiceNo=SI.InvoiceNo 
				  Group by IM.itemDescription
				  for XML path('') ),1,1,'') ItemDescription
		,Stuff((Select ','+ UM.Alias
				 From Sales.InvoiceItemDetails ID
				 Inner Join masterdata.mUnitMaster UM on UM.UnitNo=ID.unitNo				 
				  where id.InvoiceNo=SI.InvoiceNo 
				  Group by UM.Alias
				  for XML path('') ),1,1,'') Unit
		,(Select SUM(ID.BasicAmount) 
				 From Sales.InvoiceItemDetails ID
				  where id.InvoiceNo=SI.InvoiceNo
				  Group By ID.InvoiceNo 
		 )-ISNULL(DISC.TotalValue,0) as BasicAmt
		,SI.NetAmount
		,SI.LRNo LRNo
		,SI.LRDate as LRDate
		,isnull(BED.TotalValue,0)+isnull(EDU.TotalValue,0)+isnull(SHE.TotalValue,0) as ExciseAmount
		,isnull(BED.TotalValue,0) BEDValue
		,isnull(EDU.TotalValue,0) EDUValue
		,isnull(SHE.TotalValue,0) SHEValue
		,isnull(CST.MiscChargeName,VAT.MiscChargeName) VATCSTRate
		,isnull(CST.TotalValue,VAT.TotalValue) as VATCSTAmt
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.InvoiceTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 34
			   And GST.InvoiceNo = SI.InvoiceNo
			   For Xml Path ('')),1,1,'') as CGSTRate	
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.InvoiceTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 35
			   And GST.InvoiceNo = SI.InvoiceNo
			   For Xml Path ('')),1,1,'') as SGSTRate	
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.InvoiceTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 36
			   And GST.InvoiceNo = SI.InvoiceNo
			   For Xml Path ('')),1,1,'') as IGSTRate	
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.InvoiceTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 37
			   And GST.InvoiceNo = SI.InvoiceNo
			   For Xml Path ('')),1,1,'') as UGSTRate	
		,isnull(CGST.TotalValue,0) CGSTValue
		,isnull(SGST.TotalValue,0) SGSTValue
		,isnull(IGST.TotalValue,0) IGSTValue
		,isnull(UGST.TotalValue,0) UGSTValue
		,isnull(GSTCess.TotalValue,0) GSTCessValue
		,isnull(TCS.TotalValue,0) TCSValue
		,isnull(INSU.TotalValue,0) TransitInsuranceValue
		,SI.NetAmount-(isnull(BED.TotalValue,0)+isnull(EDU.TotalValue,0)+isnull(SHE.TotalValue,0)+coalesce(CST.TotalValue,VAT.TotalValue,0)
		+ isnull(CGST.TotalValue,0) + isnull(SGST.TotalValue,0) + isnull(IGST.TotalValue,0) + isnull(UGST.TotalValue,0) + isnull(GSTCess.TotalValue,0) 
		+
							   ((Select SUM(ID.BasicAmount) 
								 From Sales.InvoiceItemDetails ID
								 Where id.InvoiceNo=SI.InvoiceNo
								 Group By ID.InvoiceNo 
								 )-ISNULL(DISC.TotalValue,0)
								)
		+ ISNULL(TCS.TotalValue,0) + ISNULL(INSU.TotalValue,0) + ISNULL(PCKFWD.TotalValue,0)
				  ) [OtherCharges]
		,Stuff((select  distinct ','+  aM.AccountName 
									from Finance.accVoucherDetail VD
									--Inner Join Finance.ARDItemRule IR on IR.AccountNo=VD.AccountNo
									Inner Join masterdata.mAccountMaster aM on aM.AccountNo=VD.AccountNo
									Inner Join masterdata.mAccountGroup AG on AG.GroupNo=aM.DefaultGroupNo
									Where VD.VoucherNo=SI.VoucherNo
									And AG.GroupTypeNo=13
									Group by aM.AccountName
									For Xml path('')				
									--Having COUNT(am.accountNAme)=1
								),1,1,'') as  StockAcc
		,(
		  Select case when COUNT(distinct UnitNo)>1 then CONVERT(Decimal(15,3),Null) else SUM(Quantity) end 
		  From Sales.InvoiceItemDetails
		  Where InvoiceNo=SI.InvoiceNo
		  group by InvoiceNo	
		 )	[Quantity]	
		,(
		  Select case when COUNT(ItemNo)=1 then convert(varchar,Convert(decimal(18,2),sum(Rate) * SI.MultiplicativeRate*SI.DivisibilityRate)) else '' end 
		  From Sales.InvoiceItemDetails
		  Where InvoiceNo=SI.InvoiceNo
		  group by InvoiceNo
		 ) [Rate]
		,Stuff((Select distinct ','+'[' + ERGP.PartyBillNo +',Dt-'+convert(varchar(50),ERGP.PartyBillDate,103) +']' 
				From sales.InvoiceItemLotDetail iild
				left join inventory.invlotsummary ils on iild.InvLotSummaryNo = ils.InvLotSummaryNo
				LEFT Join Inventory.InvlotSummaryRefDetail ilrd on ilrd.InvLotSummaryNo = ils.InvLotSummaryNo 
				left Join Inventory.InvLotDetail LD on LD.InvLotSummaryNo=ils.InvLotSummaryNo 
													 And LD.DocumentNo=iild.InvoiceNo
													 And LD.ItemNo=iild.ItemNo 
													 And isnull(LD.MakeNo,0)=isnull(iild.MakeNo,0)
				left join Inventory.InvLotBillDetail IBD on ibd.InvLotSummaryNo = iild.InvLotSummaryNo 
														  And IBD.TransactionFlag='PBPB'
				left JOIN Finance.ExciseRGPart ERGP1 on ERGP1.ExciseRGPartNo = ilrd.ExciseRGPartNo  
				left join Finance.ExciseRGPart ERGP on ERGP.ExciseRGPartNo = ERGP1.RefExciseRGPartNo	
				Where iild.InvoiceNo=SI.InvoiceNo
				For Xml Path('')),1,1,'') VendorInvoiceNo,
	    SI.WayBillNo,SI.WayBillDate,SI.IRN,SI.AckNo,SI.AckDate   	
		,SI.MultiplicativeRate*SI.DivisibilityRate [Exchange Rate]
		,LEFT(DateName(MONTH,SI.DocumentDate),3)+ '-' + Convert(varchar(4),YEAR(SI.DocumentDate)) [Invoice Month]
		,ISDC.SourceDocument [Source Document]
		,FRTPE.FreightType [Freight Type]
		,Stuff((Select ','+ GM.GroupName
				 From Sales.InvoiceItemDetails ID
				 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
				 Inner Join masterdata.mSubGroupMaster SGM on SGM.SubGroupNo = IM.SubGroupNo
				 Inner Join masterdata.mGroupMaster GM on GM.GroupNo = SGM.GroupNo
				  where id.InvoiceNo=SI.InvoiceNo
				  Group by  GM.GroupName
				  for XML path('') ),1,1,'') [Group Name]
		,Stuff((Select ','+ IT.Type
				 From Sales.InvoiceItemDetails ID
				 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
				 Inner Join [GlobalData].[ItemType] IT on IT.ItemTypeNo = IM.ItemTypeNo
				 where id.InvoiceNo=SI.InvoiceNo 
				 Group by IT.Type
				  for XML path('') ),1,1,'') [Material Type]
		,SC.SalesCategory [Invoice Category]
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.InvoiceTaxDetail GST
			   Inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo
			   Inner Join masterdata.mTaxGroup tg on tg.TaxGroupNo = mc.TaxGroupNo
			   Where tg.GroupCode = 'PAFBEF' And GST.InvoiceNo = SI.InvoiceNo
			   For Xml Path ('')),1,1,'') as [PCKFWDRate]
		,ISNULL(PCKFWD.TotalValue,0) [PCKFWDValue] 
		,SI.IsCreateDC,FI.[Freight Invoice No.],FI.[Freight Invoice Date],FI.FreightPayableAmount
		, stuff((Select ',' + GSS.GSTRSectionName from Finance.VoucherGSTDetail VGD 
		    inner join GlobalData.GSTRSection GSS on GSS.GSTRSectionNo = vgd.GSTRSectionNo 
		    where SI.InvoiceNo = VGD.DocumentNo and VGD.FormCode like 'SDEI' 
			Group by GSS.GSTRSectionName
			For xml path('')
			),1,1,'')[GSTR Section]
	From  Sales.InvoiceMain SI
	Inner Join GlobalData.SalesCategory SC on SC.SalesCategoryNo=SI.InvoiceCategoryNo
	Inner Join masterdata.mVendorLocationDetail VL on VL.VendorLocationNo=SI.CustomerLocationNo	
	Inner Join masterdata.mVendorLocationInformation VLI on VLI.VendorLocationNo=VL.VendorLocationNo
	LEft Join GlobalData.GSTRegistrationType RT on RT.GSTRegistrationTypeNo=VL.GSTRegistrationTypeNo
	Left Join MAsterdata.mStateMaster ST on ST.StateNo=VL.StateNo
	Inner Join masterdata.mCompanymaster CM on CM.CompanyNo=SI.CompanyNo
	Inner Join #TempSRComp CT on CT.CompanyNo=SI.CompanyNo
	Left Join (
				Select DD.RefDocNo,DD.PayableAmount [FreightPayableAmount]
				,FIM.DocumentNoYearly [Freight Invoice No.]
				,FIM.DocumentDate [Freight Invoice Date]
				From Finance.FreightInvoiceDocumentDetail DD
				Inner Join Finance.FreightInvoiceMain FIM on FIM.FreightInvoiceNo=DD.FreightInvoiceNo
				Where FIM.FreightDocumentNo=4				
			  )FI on FI.RefDocNo = SI.InvoiceNo
	Left Join (
	            Select BED.InvoiceNo  ,sum(BED.TotalValue) TotalValue
				From Sales.InvoiceTaxDetail BED 
				      Inner Join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo
				Where mc.TaxGroupNo = 3----BED
				Group By  BED.InvoiceNo
			  ) BED on BED.InvoiceNo=SI.InvoiceNo
	Left Join (
	            Select BED.InvoiceNo  ,sum(BED.TotalValue) TotalValue
				From Sales.InvoiceTaxDetail BED 
				     Inner Join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo
				Where mc.TaxGroupNo = 4---EDU
				Group By  BED.InvoiceNo
			  ) EDU on EDU.InvoiceNo=SI.InvoiceNo
	Left Join (
	            Select BED.InvoiceNo  ,sum(BED.TotalValue) TotalValue
				from Sales.InvoiceTaxDetail BED 
				inner join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo
				where mc.TaxGroupNo = 5
				group by  BED.InvoiceNo
				) SHE on SHE.InvoiceNo=SI.InvoiceNo	
	Left Join (Select BED.InvoiceNo  ,sum(BED.TotalValue) TotalValue
				from Sales.InvoiceTaxDetail BED 
				inner join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo
				where mc.TaxGroupNo = 18
				group by  BED.InvoiceNo
				) DISC on DISC.InvoiceNo=SI.InvoiceNo									
	Left Join (Select CST.InvoiceNo  ,MiscChargeName, mc.Rate CSTRate,CST.TotalValue
				from Sales.InvoiceTaxDetail CST 
				inner join masterdata.mMiscCharges mc on CST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 11
				) CST on CST.InvoiceNo=SI.InvoiceNo
	Left JOin (Select VAT.InvoiceNo  ,MiscChargeName, mc.Rate VATRate,VAT.TotalValue
				from Sales.InvoiceTaxDetail VAT 
				inner join masterdata.mMiscCharges mc on VAT.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 12
				) VAT on VAT.InvoiceNo=SI.InvoiceNo
	Left JOin (Select GST.InvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.InvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 34
				group by  GST.InvoiceNo
				) CGST on CGST.InvoiceNo=SI.InvoiceNo
	Left JOin (Select GST.InvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.InvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 35
				group by  GST.InvoiceNo				
				) SGST on SGST.InvoiceNo=SI.InvoiceNo
	Left JOin (Select GST.InvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.InvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 36
				group by  GST.InvoiceNo
				) IGST on IGST.InvoiceNo=SI.InvoiceNo
	Left JOin (Select GST.InvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.InvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 37
				group by  GST.InvoiceNo
				) UGST on UGST.InvoiceNo=SI.InvoiceNo
	Left JOin (Select GST.InvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.InvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 38
				group by  GST.InvoiceNo
				) GSTCess on GSTCess.InvoiceNo=SI.InvoiceNo
	Left JOin (Select GST.InvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.InvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 14
				group by  GST.InvoiceNo
				) TCS on TCS.InvoiceNo=SI.InvoiceNo
	Left JOin (Select GST.InvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.InvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 39
				group by  GST.InvoiceNo
				) INSU on INSU.InvoiceNo=SI.InvoiceNo	
	Left JOin ( Select GST.InvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.InvoiceTaxDetail GST 
				Inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo
				Inner Join masterdata.mTaxGroup tg on tg.TaxGroupNo = mc.TaxGroupNo
				Where tg.GroupCode = 'PAFBEF'
				group by  GST.InvoiceNo
			) PCKFWD on PCKFWD.InvoiceNo=SI.InvoiceNo	
	Inner Join Finance.accVoucherMain VM on VM.VoucherNo=SI.VoucherNo
	Inner Join masterdata.mFBTaxBookDetail FT on FT.FBNo=VM.FBNo
	Inner Join #TaxBook TB on TB.TaxBookNo=FT.TaxBookNo		
	Inner Join [GlobalData].[DispatchSourceDocument] ISDC on ISDC.DispatchSourceNo = SI.SourceDocumentNo
	Left Join [GlobalData].[FreightType] FRTPE on FRTPE.FreightTypeNo = SI.FreightTypeNo
Where SI.DocumentDate Between @FromDate And @ToDate
		And SI.CustomerLocationNo=ISNULL(@CustomerLocationNo,SI.CustomerLocationNo)
		and SI.StatusNo <> 4
		--And isnull(TB.TaxBookNo,0)=Coalesce(@TaxBookNo,TB.TaxBookNo,0)
And ISNULL(@InvoiceType,1)=1		
				
Union all 

-- For Sales Return 
   Select 1 as [Type]
		,null InvoiceNo
		,SRM.CompanyNo
		,CM.CompanyName 
		,SRM.DocumentNoYearly
		,SRM.DocumentDate
		,VM.DocumentNoYearly as VoucherNo
		,VM.DocumentDate as VoucherDate
		,'Tax Invoice' as InvoiceType
		,'Sales Return' as SalesCategory
		,Stuff((Select distinct ','+ '[' +convert(varchar,ID.DocumentNoYearly) +']' 
					 + '['+convert(varchar(50),ID.DocumentDate,103) +']'
				 From Sales.SalesReturnItemDetail  SRID 
   					inner join Sales.SalesReturnMain RM on RM.SalesReturnNo = SRID.SalesReturnNo 
					Inner Join Sales.InvoiceMain  ID on ID.InvoiceNo = SRID.InvoiceNo 
				  where SRID.SalesReturnNO = SRM.SalesReturnNo 
				  And RM.SalesReturnSourceNo =2
				 -- order by AM.DocumentDate,AM.DocumentNoYearly 
				  for XML path('') ),1,1,'') as [RefNo/Date]
		,VL.VendorName [Party Name] 
		,VL.FullAddress
		,VLI.TINNo as PartyTinNo
		,VL.GSTINNo
		,ST.StateName
		,ST.GSTStateCode
		,RT.RegistrationType [GSTRegistrationType]
		,Stuff((Select ','+ HS.HSNSACCode
				 From Sales.SalesReturnItemDetail ID				 
				 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
				 Inner Join Globaldata.HSNSACCode HS on HS.HSNSACCodeNo=IM.HSNSACCodeNo
				 where id.SalesReturnNo=SRM.SalesReturnNo 
				 Group by HS.HSNSACCode
				  for XML path('') ),1,1,'') HSNSACCode		                            
		,Stuff((Select ','+ IM.ItemDescription
				 From Sales.SalesReturnItemDetail  SRID
				 Inner Join masterdata.mItemMaster IM on IM.ItemNo=SRID.ItemNo
				  where SRID.SalesReturnNo = SRM.SalesReturnNo
				  Group by IM.itemDescription
				  for XML path('') ),1,1,'') ItemDescription
		,Stuff((Select ','+ UM.Alias
				 From Sales.SalesReturnItemDetail ID
				 Inner Join masterdata.mUnitMaster UM on UM.UnitNo=ID.unitNo				 
				  where id.SalesReturnNo=SRM.SalesReturnNo
				  Group by UM.Alias
				  for XML path('') ),1,1,'') Unit
		,-((Select SUM(ID.BasicAmount) 
				 From Sales.SalesReturnItemDetail  ID
				  where ID.SalesReturnNo = SRM.SalesReturnNO
				  Group By ID.SalesReturnNo 
		 )-ISNULL(DISC.TotalValue,0)) as BasicAmt
		,-(ID.NetAmount) as  NetAmount
		,SRM.LRNo LRNo
		,SRM.LRDate as LRDate
		,isnull(BED.TotalValue,0)+isnull(EDU.TotalValue,0)+isnull(SHE.TotalValue,0) as ExciseAmount
		,-(isnull(BED.TotalValue,0)) BEDValue
		,-(isnull(EDU.TotalValue,0)) EDUValue
		,-(isnull(SHE.TotalValue,0)) SHEValue
		,isnull(CST.MiscChargeName,VAT.MiscChargeName) VATCSTRate
		,-(isnull(CST.TotalValue,VAT.TotalValue)) as VATCSTAmt
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.SalesReturnTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 34
			   And GST.SalesReturnNo = SRM.SalesReturnNo
			   For Xml Path ('')),1,1,'') as CGSTRate	
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.SalesReturnTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 35
			   And GST.SalesReturnNo = SRM.SalesReturnNo
			   For Xml Path ('')),1,1,'') as SGSTRate	
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.SalesReturnTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 36
			   And GST.SalesReturnNo = SRM.SalesReturnNo
			   For Xml Path ('')),1,1,'') as IGSTRate	
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.SalesReturnTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 37
			   And GST.SalesReturnNo = SRM.SalesReturnNo
			   For Xml Path ('')),1,1,'') as UGSTRate
		,isnull(CGST.TotalValue,0) CGSTValue
		,isnull(SGST.TotalValue,0) SGSTValue
		,isnull(IGST.TotalValue,0) IGSTValue
		,isnull(UGST.TotalValue,0) UGSTValue
		,isnull(GSTCess.TotalValue,0) GSTCessValue
		,isnull(TCS.TotalValue,0) TCSValue
		,isnull(INSU.TotalValue,0) TransitInsuranceValue	
		,-(ID.NetAmount
		
		+(isnull(BED.TotalValue,0)+isnull(EDU.TotalValue,0)+isnull(SHE.TotalValue,0)+coalesce(CST.TotalValue,VAT.TotalValue,0)
		+ isnull(CGST.TotalValue,0) + isnull(SGST.TotalValue,0) + isnull(IGST.TotalValue,0) + isnull(UGST.TotalValue,0) + isnull(GSTCess.TotalValue,0) 
		-
							   ((Select SUM(ID.BasicAmount) 
								 From Sales.SalesReturnItemDetail ID
								 Where ID.SalesReturnNo=SRM.SalesReturnNo
								 Group By ID.SalesReturnNo 
								 )-ISNULL(DISC.TotalValue,0)
								)
		+ ISNULL(TCS.TotalValue,0) + ISNULL(INSU.TotalValue,0)+ ISNULL(PCKFWD.TotalValue,0)								
				  )) [OtherCharges]
		,Stuff((select  distinct ','+  aM.AccountName 
									from Finance.accVoucherDetail VD
									--Inner Join Finance.ARDItemRule IR on IR.AccountNo=VD.AccountNo
									Inner Join masterdata.mAccountMaster aM on aM.AccountNo=VD.AccountNo
									Inner Join masterdata.mAccountGroup AG on AG.GroupNo=aM.DefaultGroupNo
									Where VD.VoucherNo=SRM.VoucherNo
									And AG.GroupTypeNo=13
									Group by aM.AccountName
									For Xml path('')				
									--Having COUNT(am.accountNAme)=1
								),1,1,'') as  StockAcc
		,(
		  Select   (-1.00) *(SUM(SRID.ReceivedQty)) as Quantity 
		  From Sales.SalesReturnItemDetail  SRID
		  Where SRID.SalesReturnNo  = SRM.SalesReturnNO
		  group by SRID.SalesReturnNo 	
		 )	[Quantity]	
		,(
		  Select convert(varchar ,Convert(decimal(18,2),AVG(Rate)*SRM.MultiplicativeRate*SRM.DivisibilityRate)) Rate
		  From Sales.SalesReturnItemDetail SRID
		  Where SRID.SalesReturnNo = SRM.SalesReturnNO
		  group by SalesReturnNo 
		 ) [Rate]
		,null VendorInvoiceNo,
	 SRM.WayBillNo,SRM.WayBillDate, SRM.IRN IRN,SRM.AckNo,SRM.AckDate 
	 ,SRM.MultiplicativeRate*SRM.DivisibilityRate [Exchange Rate]
	 ,LEFT(DateName(MONTH,SRM.DocumentDate),3)+ '-' + Convert(varchar(4),YEAR(SRM.DocumentDate)) [Invoice Month]
	 ,SRDOC.SourceDocument [Source Document]
	 ,FRTPE.FreightType [Freight Type]
	 ,Stuff((Select ','+ GM.GroupName
				 From Sales.SalesReturnItemDetail ID
				 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
				 Inner Join masterdata.mSubGroupMaster SGM on SGM.SubGroupNo = IM.SubGroupNo
				 Inner Join masterdata.mGroupMaster GM on GM.GroupNo = SGM.GroupNo
				  where id.InvoiceNo= SRM.SalesReturnNo
				  Group by GM.GroupName
				  for XML path('') ),1,1,'') [Group Name]
		,Stuff((Select ','+ IT.Type
				 From Sales.SalesReturnItemDetail ID
				 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
				 Inner Join [GlobalData].[ItemType] IT on IT.ItemTypeNo = IM.ItemTypeNo
				  where id.InvoiceNo= SRM.SalesReturnNo
				  Group by IT.Type
				  for XML path('') ),1,1,'') [Material Type]
	     ,ISNULL(STUFF((Select ','+SC.SalesCategory
					From  [Sales].[SalesReturnReferenceDetail] REFD
					Inner Join Sales.InvoiceMain IVM on IVM.InvoiceNo =REFD.InvoiceNo 
					Inner Join GlobalData.SalesCategory SC on SC.SalesCategoryNo=IVM.InvoiceCategoryNo and SRM.SalesReturnSourceNo = 2 -- tax invoice 
					Where REFD.SalesReturnNo  = SRM.SalesReturnNo 
					Group by SC.SalesCategory
					for XML path('')),1,1,'')
		            ,
				STUFF((	Select ','+SC.SalesCategory
				From [Sales].[SalesReturnItemDetail] SRID
				Inner Join Sales.SalesOrderAmendmentMain SOA on SOA.SalesOrderAmendmentNo = SRID.SalesOrderAmendmentNo 
				Inner Join GlobalData.SalesCategory SC on SC.SalesCategoryNo= SOA.SalesCategoryNo and SRM.SalesReturnSourceNo = 3 -- commercial invoice
				Where SRID.SalesReturnNo = SRM.SalesReturnNo
				Group by SC.SalesCategory
				for XML path('')),1,1,'')
				) [Invoice Category]
			,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.SalesReturnTaxDetail GST
			   Inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo
			   Inner Join masterdata.mTaxGroup tg on tg.TaxGroupNo = mc.TaxGroupNo
			   Where tg.GroupCode = 'PAFBEF'
			   And GST.SalesReturnNo = SRM.SalesReturnNo
			   For Xml Path ('')),1,1,'') as [PCKFWDRate]
			 ,ISNULL(PCKFWD.TotalValue,0) [PCKFWDValue]	
,Convert(Bit,0) IsCreateDC,FI.[Freight Invoice No.],FI.[Freight Invoice Date],FI.FreightPayableAmount
, stuff((Select ',' + GSS.GSTRSectionName from Finance.VoucherGSTDetail VGD 
	inner join GlobalData.GSTRSection GSS on GSS.GSTRSectionNo = vgd.GSTRSectionNo 
	where SRM.SalesReturnNo = VGD.DocumentNo and VGD.FormCode like 'SDSR' 
	Group by GSS.GSTRSectionName
	For xml path('')
	),1,1,'')[GSTR Section]
From  Sales.SalesReturnMain  SRM
Inner Join masterdata.mVendorLocationDetail VL on VL.VendorLocationNo = SRM.CustomerLocationNo
Inner Join masterdata.mVendorLocationInformation VLI on VLI.VendorLocationNo=VL.VendorLocationNo
LEft Join GlobalData.GSTRegistrationType RT on RT.GSTRegistrationTypeNo=VL.GSTRegistrationTypeNo
Left Join MAsterdata.mStateMaster ST on ST.StateNo=VL.StateNo
Inner Join masterdata.mCompanymaster CM on CM.CompanyNo= SRM.CompanyNo
Inner Join #TempSRComp CT on CT.CompanyNo=SRM.CompanyNo
Left Join (
			Select DD.RefDocNo,DD.PayableAmount [FreightPayableAmount]
			,FIM.DocumentNoYearly [Freight Invoice No.]
			,FIM.DocumentDate [Freight Invoice Date]
			From Finance.FreightInvoiceDocumentDetail DD
			Inner Join Finance.FreightInvoiceMain FIM on FIM.FreightInvoiceNo=DD.FreightInvoiceNo
			Where FIM.FreightDocumentNo=10
		  )FI on FI.RefDocNo = SRM.SalesReturnNo
Inner join  ( Select SRID.SAlesReturnNo ,Sum(NetAmount) as NetAmount,SRID.InvoiceNo  
				From Sales.SalesReturnItemDetail SRID 
				Where SRID.InvoiceNo  is not null
				Group By SRID.SalesReturnNo ,SRID.InvoiceNo 
               )ID on ID.SalesReturnNo = SRM.SalesReturnNo
Left Join (
            Select BED.SalesReturnNo ,-1 * sum(BED.TotalValue) TotalValue
			From Sales.SalesReturnTaxDetail  BED 
			      Inner Join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo
			Where mc.TaxGroupNo = 3----BED
			Group By  BED.SalesReturnNo 
		  ) BED on BED.SAlesReturnNO=SRM.SAlesReturnNO
Left Join (
            Select BED.SalesReturnNo ,-1 * sum(BED.TotalValue) TotalValue
			From Sales.SalesReturnTaxDetail  BED 
			     Inner Join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo
			Where mc.TaxGroupNo = 4---EDU
			Group By  BED.SalesReturnNo 
		  ) EDU on EDU.SAlesReturnNO=SRM.SAlesReturnNO
Left Join (
            Select BED.SalesReturnNo ,-1 * sum(BED.TotalValue) TotalValue
			from Sales.SalesReturnTaxDetail   BED 
			inner join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo
			where mc.TaxGroupNo = 5
			group by  BED.SalesReturnNo 
			) SHE on SHE.SalesReturnNo = SRM.SalesReturnNo 	
Left Join (Select BED.SalesReturnNo  ,sum(BED.TotalValue) TotalValue
			from Sales.SalesReturnTaxDetail BED 
			inner join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo
			where mc.TaxGroupNo = 18
			group by  BED.SalesReturnNo
			) DISC on DISC.SalesReturnNo=SRM.SalesReturnNo									
Left Join (Select CST.SalesReturnNo  ,MiscChargeName, mc.Rate CSTRate,-1 * CST.TotalValue TotalValue
			from Sales.SalesReturnTaxDetail CST 
			inner join masterdata.mMiscCharges mc on CST.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 11
			) CST on CST.SalesReturnNo = SRM.SalesReturnNo
Left JOin (Select VAT.SalesReturnNo  ,MiscChargeName, mc.Rate VATRate,-1 * VAT.TotalValue TotalValue
			from Sales.SalesReturnTaxDetail VAT 
			inner join masterdata.mMiscCharges mc on VAT.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 12
			) VAT on VAT.SalesReturnNo = SRM.SalesReturnNo
Left JOin (Select GST.SalesReturnNo  ,-1 * Sum(GST.TotalValue) TotalValue
			from Sales.SalesReturnTaxDetail GST 
			inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 34
			group by  GST.SalesReturnNo
			) CGST on CGST.SalesReturnNo=SRM.SalesReturnNo
Left JOin (Select GST.SalesReturnNo  ,-1 * Sum(GST.TotalValue) TotalValue
			from Sales.SalesReturnTaxDetail GST 
			inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 35
			group by  GST.SalesReturnNo
			) SGST on SGST.SalesReturnNo=SRM.SalesReturnNo
Left JOin (Select GST.SalesReturnNo  ,-1 * Sum(GST.TotalValue) TotalValue
			from Sales.SalesReturnTaxDetail GST 
			inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 36
			group by  GST.SalesReturnNo
			) IGST on IGST.SalesReturnNo=SRM.SalesReturnNo
Left JOin (Select GST.SalesReturnNo  ,-1 * Sum(GST.TotalValue) TotalValue
			from Sales.SalesReturnTaxDetail GST 
			inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 37
			group by  GST.SalesReturnNo
			) UGST on UGST.SalesReturnNo=SRM.SalesReturnNo
Left JOin (Select GST.SalesReturnNo  ,-1 * Sum(GST.TotalValue) TotalValue
			from Sales.SalesReturnTaxDetail GST 
			inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 38
			group by  GST.SalesReturnNo
			) GSTCess on GSTCess.SalesReturnNo=SRM.SalesReturnNo
Left JOin (Select GST.SalesReturnNo  ,-1 * Sum(GST.TotalValue) TotalValue
			from Sales.SalesReturnTaxDetail GST 
			inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 14
			group by  GST.SalesReturnNo
			) TCS on TCS.SalesReturnNo=SRM.SalesReturnNo
Left JOin (Select GST.SalesReturnNo  ,-1 * Sum(GST.TotalValue) TotalValue
			from Sales.SalesReturnTaxDetail GST 
			inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 39
			group by  GST.SalesReturnNo
			) INSU on INSU.SalesReturnNo=SRM.SalesReturnNo			
	Left JOin ( Select GST.SalesReturnNo  ,-1 * Sum(GST.TotalValue) TotalValue
				from Sales.SalesReturnTaxDetail GST 
				Inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo
				Inner Join masterdata.mTaxGroup tg on tg.TaxGroupNo = mc.TaxGroupNo
				Where tg.GroupCode = 'PAFBEF'
				group by  GST.SalesReturnNo
			) PCKFWD on PCKFWD.SalesReturnNo=SRM.SalesReturnNo			
	Inner Join Finance.accVoucherMain VM on VM.VoucherNo=SRM.VoucherNo
	Inner Join masterdata.mFBTaxBookDetail FT on FT.FBNo=VM.FBNo
	Inner Join #TaxBook TB on TB.TaxBookNo=FT.TaxBookNo		
	Inner Join [GlobalData].[SalesReturnSourceDocument] SRDOC on SRDOC.SalesReturnSourceNo = SRM.SalesReturnSourceNo
	Inner Join [GlobalData].[FreightType] FRTPE on FRTPE.FreightTypeNo = SRM.FreightTypeNo
Where SRM.DocumentDate Between @FromDate And @ToDate
		And SRM.CustomerLocationNo = ISNULL(@CustomerLocationNo,SRM.CustomerLocationNo)
		And ID.INvoiceNo is not null
And ISNULL(@InvoiceType,1)=1		
		--And isnull(TB.TaxBookNo,0)=Coalesce(@TaxBookNo,TB.TaxBookNo,0)		
		
		
Union All
---Commercial Invoice

Select 2 as [Type]
,CI.CommercialInvoiceNo
,CI.CompanyNo
,CMR.CompanyName
,CI.DocumentNoYearly
,CI.DocumentDate
,VM.DocumentNoYearly  as VoucherNo
,VM.DocumentDate AS VoucherDate 
,'Tax Invoice' as InvoiceType
,'Tax Invoice' as [salesCategory]
,isnull(Stuff((Select distinct ','+ '[' +convert(varchar,AM.DocumentNoYearly) +']' 
             + '['+convert(varchar(50),AM.DocumentDate,103) +']'
         From Sales.SalesOrderAmendmentMain AM 
         Inner Join Sales.CommercialInvoiceItemDetails ID on ID.SalesOrderAmendmentNo=AM.SalesOrderAmendmentNo
          where id.CommercialInvoiceNo=CI.CommercialInvoiceNo 
         -- order by AM.DocumentDate,AM.DocumentNoYearly 
          for XML path('') ),1,1,''),CI.RefNoDate) as [RefNo/Date]
,VL.VendorName [Party Name]
,VL.FullAddress 
,VLI.TINNo as PartyTinNo
		,VL.GSTINNo
		,ST.StateName
		,ST.GSTStateCode
		,RT.RegistrationType [GSTRegistrationType]
		,Stuff((Select ','+ HS.HSNSACCode
				 From Sales.CommercialInvoiceItemDetails ID				 
				 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
				 Inner Join Globaldata.HSNSACCode HS on HS.HSNSACCodeNo=IM.HSNSACCodeNo
				 where id.CommercialInvoiceNo=CI.CommercialInvoiceNo 
				 Group by HS.HSNSACCode
				  for XML path('') ),1,1,'') HSNSACCode                            
,Stuff((Select ','+ IM.ItemDescription
         From Sales.CommercialInvoiceItemDetails ID
         Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
          where id.CommercialInvoiceNo=CI.CommercialInvoiceNo 
          Group by IM.itemDescription
          for XML path('') ),1,1,'') ItemDescription
,Stuff((Select ','+ UM.Alias
		 From Sales.CommercialInvoiceItemDetails ID
		 Inner Join masterdata.mUnitMaster UM on UM.UnitNo=ID.unitNo				 
		  where id.CommercialInvoiceNo=CI.CommercialInvoiceNo
		  Group by UM.Alias
		  for XML path('') ),1,1,'') Unit          
,(Select SUM(ID.BasicAmount)
         From Sales.CommercialInvoiceItemDetails ID 
          where id.CommercialInvoiceNo=CI.CommercialInvoiceNo
          Group By ID.CommercialInvoiceNo 
 )-ISNULL(DISC.TotalValue,0) as BasicAmt
,CI.NetAmount
,CI.LRNo LRNo
,CI.LRDate as LRDate
,isnull(BED.TotalValue,0)+isnull(EDU.TotalValue,0)+isnull(SHE.TotalValue,0) as ExciseAmount
,isnull(BED.TotalValue,0) BEDValue
,isnull(EDU.TotalValue,0) EDUValue
,isnull(SHE.TotalValue,0) SHEValue
,isnull(CST.MiscChargeName,VAT.MiscChargeName) VATCSTRate
,isnull(CST.TotalValue,VAT.TotalValue) as VATCSTAmt
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.CommercialInvoiceTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 34
			   And GST.CommercialInvoiceNo = CI.CommercialInvoiceNo
			   For Xml Path ('')),1,1,'') as CGSTRate	
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.CommercialInvoiceTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 35
			   And GST.CommercialInvoiceNo = CI.CommercialInvoiceNo
			   For Xml Path ('')),1,1,'') as SGSTRate	
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.CommercialInvoiceTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 36
			   And GST.CommercialInvoiceNo = CI.CommercialInvoiceNo
			   For Xml Path ('')),1,1,'') as IGSTRate	
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.CommercialInvoiceTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 37
			   And GST.CommercialInvoiceNo = CI.CommercialInvoiceNo
			   For Xml Path ('')),1,1,'') as UGSTRate	
		,isnull(CGST.TotalValue,0) CGSTValue
		,isnull(SGST.TotalValue,0) SGSTValue
		,isnull(IGST.TotalValue,0) IGSTValue
		,isnull(UGST.TotalValue,0) UGSTValue
		,isnull(GSTCess.TotalValue,0) GSTCessValue
		,isnull(TCS.TotalValue,0) TCSValue
		,isnull(INSU.TotalValue,0) TransitInsuranceValue		
,CI.NetAmount-(isnull(BED.TotalValue,0)+isnull(EDU.TotalValue,0)+isnull(SHE.TotalValue,0)+coalesce(CST.TotalValue,VAT.TotalValue,0)
+ isnull(CGST.TotalValue,0) + isnull(SGST.TotalValue,0) + isnull(IGST.TotalValue,0) + isnull(UGST.TotalValue,0) + isnull(GSTCess.TotalValue,0) 
+
		               ((Select SUM(ID.BasicAmount) 
                         From Sales.CommercialInvoiceItemDetails ID
                         Where id.CommercialInvoiceNo=CI.CommercialInvoiceNo
                         Group By ID.CommercialInvoiceNo 
                         )-ISNULL(DISC.TotalValue,0)
                        )
		+ ISNULL(TCS.TotalValue,0) + ISNULL(INSU.TotalValue,0)  + ISNULL(PCKFWD.TotalValue,0)                 
		  ) [OtherCharges]
,Stuff((select  distinct ','+  aM.AccountName 
							from Finance.accVoucherDetail VD
							--Inner Join Finance.ARDItemRule IR on IR.AccountNo=VD.AccountNo
							Inner Join masterdata.mAccountMaster aM on aM.AccountNo=VD.AccountNo
							Inner Join masterdata.mAccountGroup AG on AG.GroupNo=aM.DefaultGroupNo
							Where VD.VoucherNo=CI.VoucherNo
							And AG.GroupTypeNo=13
							Group by aM.AccountName
							For Xml path('')				
							--Having COUNT(am.accountNAme)=1
						),1,1,'') as  StockAcc
,(
  Select case when COUNT(distinct UnitNo)>1 then CONVERT(Decimal(15,3),Null) else SUM(Quantity) end 
  From Sales.CommercialInvoiceItemDetails
  Where CommercialInvoiceNo=CI.CommercialInvoiceNo
  group by CommercialInvoiceNo	
)	[Quantity]	
,(
  Select case when COUNT(ItemNo)=1 then convert(varchar,Convert(decimal(18,2),sum(Rate) * CI.MultiplicativeRate*CI.DivisibilityRate)) else '' end 
  From Sales.CommercialInvoiceItemDetails
  Where CommercialInvoiceNo=CI.CommercialInvoiceNo
  group by CommercialInvoiceNo
) [Rate]
,Stuff((Select distinct ','+'[' + IBD.BillNoYearly +',Dt-'+convert(varchar(50),IBD.BillDate,103) +']' 
		From sales.CommercialInvoiceItemLotDetail iild
		left join inventory.invlotsummary ils on iild.InvLotSummaryNo = ils.InvLotSummaryNo
		Left Join Inventory.InvlotSummaryRefDetail ilrd on ilrd.InvlotSummaryNo= ils.invlotSummaryNo
		left Join Inventory.InvLotDetail LD on LD.InvLotSummaryNo=ils.InvLotSummaryNo 
											 And LD.DocumentNo=iild.CommercialInvoiceNo
											 And LD.ItemNo=iild.ItemNo 
											 And isnull(LD.MakeNo,0)=isnull(iild.MakeNo,0)
		left join Inventory.InvLotBillDetail IBD on ibd.InvLotSummaryNo = iild.InvLotSummaryNo 
												  And IBD.TransactionFlag = 'PBPB'
		--left JOIN Finance.ExciseRGPart ERGP1 on ERGP1.ExciseRGPartNo = ilrd.ExciseRGPartNo  
		--left join Finance.ExciseRGPart ERGP on ERGP.ExciseRGPartNo = ERGP1.RefExciseRGPartNo	
		Where iild.CommercialInvoiceNo = CI.CommercialInvoiceNo
		For Xml Path('')),1,1,'') VendorInvoiceNo,	
		CI.WayBillNo, CI.WayBillDate,CI.IRN,CI.AckNo,CI.AckDate
		,CI.MultiplicativeRate*CI.DivisibilityRate [Exchange Rate]
		 ,LEFT(DateName(MONTH,CI.DocumentDate),3)+ '-' + Convert(varchar(4),YEAR(CI.DocumentDate)) [Invoice Month]
		 ,SRDOC.SourceDocument [Source Document]
		 ,FRTPE.FreightType [Freight Type]
		 ,Stuff((Select ','+ GM.GroupName
					 From Sales.CommercialInvoiceItemDetails ID
					 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
					 Inner Join masterdata.mSubGroupMaster SGM on SGM.SubGroupNo = IM.SubGroupNo
					 Inner Join masterdata.mGroupMaster GM on GM.GroupNo = SGM.GroupNo
					  where id.CommercialInvoiceNo= CI.CommercialInvoiceNo
					  Group by GM.GroupName
					  for XML path('') ),1,1,'') [Group Name]
			,Stuff((Select ','+ IT.Type
					 From Sales.CommercialInvoiceItemDetails ID
					 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
					 Inner Join [GlobalData].[ItemType] IT on IT.ItemTypeNo = IM.ItemTypeNo
					  where id.CommercialInvoiceNo = CI.CommercialInvoiceNo
					  Group by IT.Type
				  for XML path('') ),1,1,'') [Material Type]
		    ,STUFF((
					Select ','+ SC.SalesCategory
					From Sales.CommercialInvoiceItemDetails CID 
					Inner Join Sales.SalesOrderAmendmentMain SOA on SOA.SalesOrderAmendmentNo = CID.SalesOrderAmendmentNo
					Inner Join GlobalData.SalesCategory SC on SC.SalesCategoryNo = SOA.SalesCategoryNo
					Where CID.CommercialInvoiceNo = CI.CommercialInvoiceNo
					Group by SC.SalesCategory
					FOR XML PATH('')
		           ),1,1,'') [Invoice Category]
		   , Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.CommercialInvoiceTaxDetail GST
			   Inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo
			   Inner Join masterdata.mTaxGroup tg on tg.TaxGroupNo = mc.TaxGroupNo
			   Where tg.GroupCode = 'PAFBEF'
			   And GST.CommercialInvoiceNo = CI.CommercialInvoiceNo
			   For Xml Path ('')),1,1,'') as [PCKFWDRate]
			,ISNULL(PCKFWD.TotalValue,0) [PCKFWDValue]
,Convert(Bit,0) IsCreateDC,FI.[Freight Invoice No.],FI.[Freight Invoice Date],FI.FreightPayableAmount			 			
, stuff((Select ',' + GSS.GSTRSectionName from Finance.VoucherGSTDetail VGD 
	inner join GlobalData.GSTRSection GSS on GSS.GSTRSectionNo = vgd.GSTRSectionNo 
	where CI.CommercialInvoiceNo = VGD.DocumentNo and VGD.FormCode like 'SDCI' 
	Group by GSS.GSTRSectionName
	For xml path('')
	),1,1,'')[GSTR Section]
From Sales.CommercialInvoiceMain CI
Inner Join masterdata.mVendorLocationDetail VL on VL.VendorLocationNo=CI.CustomerLocationNo
Inner Join masterdata.mVendorLocationInformation VLI on VLI.VendorLocationNo=VL.VendorLocationNo
	LEft Join GlobalData.GSTRegistrationType RT on RT.GSTRegistrationTypeNo=VL.GSTRegistrationTypeNo
	Left Join MAsterdata.mStateMaster ST on ST.StateNo=VL.StateNo
Inner Join masterdata.mCompanymaster CMR on CMR.CompanyNo=CI.CompanyNo
Inner Join #TempSRComp CT on CT.CompanyNo=CI.CompanyNo
Left Join (
			Select DD.RefDocNo,DD.PayableAmount [FreightPayableAmount]
			,FIM.DocumentNoYearly [Freight Invoice No.]
			,FIM.DocumentDate [Freight Invoice Date]
			From Finance.FreightInvoiceDocumentDetail DD
			Inner Join Finance.FreightInvoiceMain FIM on FIM.FreightInvoiceNo=DD.FreightInvoiceNo
			Where FIM.FreightDocumentNo=5
		  )FI on FI.RefDocNo = CI.CommercialInvoiceNo
Left Join (Select BED.CommercialInvoiceNo  ,sum(BED.TotalValue) TotalValue
			from Sales.CommercialInvoiceTaxDetail BED 
			inner join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 3
			group by  BED.CommercialInvoiceNo
			) BED on BED.CommercialInvoiceNo=CI.CommercialInvoiceNo	
Left Join (Select BED.CommercialInvoiceNo  ,sum(BED.TotalValue) TotalValue
			from Sales.CommercialInvoiceTaxDetail BED 
			inner join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 4
			group by  BED.CommercialInvoiceNo
			) EDU on EDU.CommercialInvoiceNo=CI.CommercialInvoiceNo	
Left Join (Select BED.CommercialInvoiceNo  ,sum(BED.TotalValue) TotalValue
			from Sales.CommercialInvoiceTaxDetail BED 
			inner join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 5
			group by  BED.CommercialInvoiceNo
			) SHE on SHE.CommercialInvoiceNo=CI.CommercialInvoiceNo	
Left Join (Select BED.CommercialInvoiceNo  ,sum(BED.TotalValue) TotalValue
			from Sales.CommercialInvoiceTaxDetail BED 
			inner join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 18
			group by  BED.CommercialInvoiceNo
			) DISC on DISC.CommercialInvoiceNo=CI.CommercialInvoiceNo										
Left Join (Select CST.CommercialInvoiceNo  ,MiscChargeName, mc.Rate CSTRate,CST.TotalValue
			from Sales.CommercialInvoiceTaxDetail CST 
			inner join masterdata.mMiscCharges mc on CST.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 11
			) CST on CST.CommercialInvoiceNo=CI.CommercialInvoiceNo
Left JOin (Select VAT.CommercialInvoiceNo  ,MiscChargeName, mc.Rate VATRate,VAT.TotalValue
			from Sales.CommercialInvoiceTaxDetail VAT 
			inner join masterdata.mMiscCharges mc on VAT.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 12
			) VAT on VAT.CommercialInvoiceNo=CI.CommercialInvoiceNo
	Left JOin (Select GST.CommercialInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.CommercialInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 34
				group by  GST.CommercialInvoiceNo
				) CGST on CGST.CommercialInvoiceNo=CI.CommercialInvoiceNo
	Left JOin (Select GST.CommercialInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.CommercialInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 35
				group by  GST.CommercialInvoiceNo
				) SGST on SGST.CommercialInvoiceNo=CI.CommercialInvoiceNo
	Left JOin (Select GST.CommercialInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.CommercialInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 36
				group by  GST.CommercialInvoiceNo
				) IGST on IGST.CommercialInvoiceNo=CI.CommercialInvoiceNo
	Left JOin (Select GST.CommercialInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.CommercialInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 37
				group by  GST.CommercialInvoiceNo
				) UGST on UGST.CommercialInvoiceNo=CI.CommercialInvoiceNo
	Left JOin (Select GST.CommercialInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.CommercialInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 38
				group by  GST.CommercialInvoiceNo
				) GSTCess on GSTCess.CommercialInvoiceNo=CI.CommercialInvoiceNo
	Left JOin (Select GST.CommercialInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.CommercialInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 14
				group by  GST.CommercialInvoiceNo
				) TCS on TCS.CommercialInvoiceNo=CI.CommercialInvoiceNo
	Left JOin (Select GST.CommercialInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.CommercialInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 39
				group by  GST.CommercialInvoiceNo
				) INSU on INSU.CommercialInvoiceNo=CI.CommercialInvoiceNo		
	Left JOin (Select GST.CommercialInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.CommercialInvoiceTaxDetail GST 
				Inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo
				Inner Join masterdata.mTaxGroup tg on tg.TaxGroupNo = mc.TaxGroupNo
				Where tg.GroupCode = 'PAFBEF'
				group by  GST.CommercialInvoiceNo
				)PCKFWD on PCKFWD.CommercialInvoiceNo=CI.CommercialInvoiceNo		
Inner Join Finance.accVoucherMain VM on VM.VoucherNo=CI.VoucherNo
Inner Join masterdata.mFBTaxBookDetail FT on FT.FBNo=VM.FBNo
Inner Join #TaxBook TB on TB.TaxBookNo=FT.TaxBookNo				
Inner Join [GlobalData].[DispatchSourceDocument] SRDOC on SRDOC.DispatchSourceNo = CI.SourceDocumentNo
Left Join GlobalData.FreightType FRTPE on FRTPE.FreightTypeNo = CI.FreightTypeNo
where CI.SourceDocumentNo not in (5,6,10)
		And CI.DocumentDate Between @FromDate And @ToDate
		And CI.CustomerLocationNo=ISNULL(@CustomerLocationNo,CI.CustomerLocationNo)
		And CI.StatusNo <> 4
		--And isnull(TB.TaxBookNo,0)=Coalesce(@TaxBookNo,TB.TaxBookNo,0)
And ISNULL(@InvoiceType,2)=2
Union all 

-- For Sales Return against commercial Invoice
   Select 2 as [Type]
		,null CommercialInvoiceNo
		,SRM.CompanyNo
		,CM.CompanyName 
		,SRM.DocumentNoYearly
		,SRM.DocumentDate
		,VM.DocumentNoYearly as VoucherNo
		,VM.DocumentDate as VoucherDate
		,'Tax Invoice' as InvoiceType
		,'Sales Return' as SalesCategory
		,Stuff((Select distinct ','+ '[' +convert(varchar,ID.DocumentNoYearly) +']' 
					 + '['+convert(varchar(50),ID.DocumentDate,103) +']'
				 From Sales.SalesReturnItemDetail  SRID 
   					inner join Sales.SalesReturnMain RM on RM.SalesReturnNo = SRID.SalesReturnNo 
					Inner Join Sales.CommercialInvoiceMain ID on ID.CommercialInvoiceNo = SRID.CommercialInvoiceNo 
				  where SRID.SalesReturnNo = SRM.SalesReturnNo 
				  And SRM.SalesReturnSourceNo = 3
				 -- order by AM.DocumentDate,AM.DocumentNoYearly 
				  for XML path('') ),1,1,'') as [RefNo/Date]
		,VL.VendorName [Party Name] 
		,VL.FullAddress
		,VLI.TINNo as PartyTinNo
		,VL.GSTINNo
		,ST.StateName
		,ST.GSTStateCode
		,RT.RegistrationType [GSTRegistrationType]
		,Stuff((Select ','+ HS.HSNSACCode
				 From Sales.SalesReturnItemDetail ID				 
				 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
				 Inner Join Globaldata.HSNSACCode HS on HS.HSNSACCodeNo=IM.HSNSACCodeNo
				 where id.SalesReturnNo=SRM.SalesReturnNo 
				 Group by HS.HSNSACCode
				  for XML path('') ),1,1,'') HSNSACCode		                            
		,Stuff((Select ','+ IM.ItemDescription
				 From Sales.SalesReturnItemDetail  SRID
				 Inner Join masterdata.mItemMaster IM on IM.ItemNo=SRID.ItemNo
				  where SRID.SalesReturnNo = SRM.SalesReturnNo
				  Group by IM.itemDescription
				  for XML path('') ),1,1,'') ItemDescription
,Stuff((Select ','+ UM.Alias
		 From Sales.SalesReturnItemDetail SRID
		 Inner Join masterdata.mUnitMaster UM on UM.UnitNo=SRID.unitNo				 
		  where SRID.SalesReturnNo = SRM.SalesReturnNo
		  Group by UM.Alias
		  for XML path('') ),1,1,'') Unit   				  
		,-((Select SUM(ID.BasicAmount) 
				 From Sales.SalesReturnItemDetail  ID
				  where ID.SalesReturnNo = SRM.SalesReturnNO
				  Group By ID.SalesReturnNo 
		 )-ISNULL(DISC.TotalValue,0)) as BasicAmt
		,-(ID.NetAmount) as  NetAmount
		,SRM.LRNo LRNo
		,SRM.LRDate as LRDate
		,isnull(BED.TotalValue,0)+isnull(EDU.TotalValue,0)+isnull(SHE.TotalValue,0) as ExciseAmount
		,-(isnull(BED.TotalValue,0)) BEDValue
		,-(isnull(EDU.TotalValue,0)) EDUValue
		,-(isnull(SHE.TotalValue,0)) SHEValue
		,isnull(CST.MiscChargeName,VAT.MiscChargeName) VATCSTRate
		,-(isnull(CST.TotalValue,VAT.TotalValue)) as VATCSTAmt
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.SalesReturnTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 34
			   And GST.SalesReturnNo = SRM.SalesReturnNo
			   For Xml Path ('')),1,1,'') as CGSTRate	
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.SalesReturnTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 35
			   And GST.SalesReturnNo = SRM.SalesReturnNo
			   For Xml Path ('')),1,1,'') as SGSTRate	
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.SalesReturnTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 36
			   And GST.SalesReturnNo = SRM.SalesReturnNo
			   For Xml Path ('')),1,1,'') as IGSTRate	
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.SalesReturnTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 37
			   And GST.SalesReturnNo = SRM.SalesReturnNo
			   For Xml Path ('')),1,1,'') as UGSTRate	
		,isnull(CGST.TotalValue,0) CGSTValue
		,isnull(SGST.TotalValue,0) SGSTValue
		,isnull(IGST.TotalValue,0) IGSTValue
		,isnull(UGST.TotalValue,0) UGSTValue
		,isnull(GSTCess.TotalValue,0) GSTCessValue
		,isnull(TCS.TotalValue,0) TCSValue
		,isnull(INSU.TotalValue,0) TransitInsuranceValue		
		,-(ID.NetAmount
		+(isnull(BED.TotalValue,0)+isnull(EDU.TotalValue,0)+isnull(SHE.TotalValue,0)+coalesce(CST.TotalValue,VAT.TotalValue,0)
		+ isnull(CGST.TotalValue,0) + isnull(SGST.TotalValue,0) + isnull(IGST.TotalValue,0) + isnull(UGST.TotalValue,0) + isnull(GSTCess.TotalValue,0) 
		-
							   ((Select SUM(ID.BasicAmount) 
								 From Sales.SalesReturnItemDetail ID
								 Where ID.SalesReturnNo=SRM.SalesReturnNo
								 Group By ID.SalesReturnNo 
								 )-ISNULL(DISC.TotalValue,0)
								)
		+ ISNULL(TCS.TotalValue,0) + ISNULL(INSU.TotalValue,0)	+ ISNULL(PCKFWD.TotalValue,0)							
				  )) [OtherCharges]
		,Stuff((select  distinct ','+  aM.AccountName 
									from Finance.accVoucherDetail VD
									--Inner Join Finance.ARDItemRule IR on IR.AccountNo=VD.AccountNo
									Inner Join masterdata.mAccountMaster aM on aM.AccountNo=VD.AccountNo
									Inner Join masterdata.mAccountGroup AG on AG.GroupNo=aM.DefaultGroupNo
									Where VD.VoucherNo=SRM.VoucherNo
									And AG.GroupTypeNo=13
									Group by aM.AccountName
									For Xml path('')				
									--Having COUNT(am.accountNAme)=1
								),1,1,'') as  StockAcc
		,(
		  Select (-1.00) * (SUM(SRID.ReceivedQty)) Quantity 
		  From Sales.SalesReturnItemDetail  SRID
		  Where SRID.SalesReturnNo  = SRM.SalesReturnNO
		  group by SRID.SalesReturnNo 	
		 )	[Quantity]	
		,(
		  Select convert(varchar ,Convert(decimal(18,2),Avg(Rate)*SRM.MultiplicativeRate*SRM.DivisibilityRate)) Rate
		  From Sales.SalesReturnItemDetail SRID
		  Where SRID.SalesReturnNo = SRM.SalesReturnNo 
		  group by SalesReturnNo 
		 ) [Rate]
		,null VendorInvoiceNo,
		SRM.WayBillNo,SRM.WayBillDate,SRM.IRN,SRM.AckNo,SRM.AckDate 	
		,SRM.MultiplicativeRate*SRM.DivisibilityRate [Exchange Rate]
		 ,LEFT(DateName(MONTH,SRM.DocumentDate),3)+ '-' + Convert(varchar(4),YEAR(SRM.DocumentDate)) [Invoice Month]
		 ,SRDOC.SourceDocument [Source Document]
		 ,FRTPE.FreightType [Freight Type]
		 ,Stuff((Select ','+ GM.GroupName
					 From Sales.SalesReturnItemDetail ID
					 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
					 Inner Join masterdata.mSubGroupMaster SGM on SGM.SubGroupNo = IM.SubGroupNo
					 Inner Join masterdata.mGroupMaster GM on GM.GroupNo = SGM.GroupNo
					  where id.InvoiceNo= SRM.SalesReturnNo
					  Group by GM.GroupName
					  for XML path('') ),1,1,'') [Group Name]
			,Stuff((Select ','+ IT.Type
					 From Sales.SalesReturnItemDetail ID
					 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
					 Inner Join [GlobalData].[ItemType] IT on IT.ItemTypeNo = IM.ItemTypeNo
					  where id.InvoiceNo= SRM.SalesReturnNo
					  Group by IT.Type
					  for XML path('') ),1,1,'') [Material Type]
			,ISNULL(
					STUFF((Select ','+SC.SalesCategory
					From  [Sales].[SalesReturnReferenceDetail] REFD
					Inner Join Sales.InvoiceMain IVM on IVM.InvoiceNo =REFD.InvoiceNo 
					Inner Join GlobalData.SalesCategory SC on SC.SalesCategoryNo=IVM.InvoiceCategoryNo and SRM.SalesReturnSourceNo = 2 -- tax invoice 
					Where REFD.SalesReturnNo  = SRM.SalesReturnNo 
					Group by SC.SalesCategory
					for XML path('')),1,1,'')
		          ,
					STUFF((	Select ','+SC.SalesCategory
					From [Sales].[SalesReturnItemDetail] SRID
					Inner Join Sales.SalesOrderAmendmentMain SOA on SOA.SalesOrderAmendmentNo = SRID.SalesOrderAmendmentNo 
					Inner Join GlobalData.SalesCategory SC on SC.SalesCategoryNo= SOA.SalesCategoryNo and SRM.SalesReturnSourceNo = 3 -- commercial invoice
					Where SRID.SalesReturnNo = SRM.SalesReturnNo
					Group by SC.SalesCategory
					for XML path('')),1,1,'')
				) [Invoice Category]
			,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			     from Sales.SalesReturnTaxDetail GST
				Inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo
				Inner Join masterdata.mTaxGroup tg on tg.TaxGroupNo = mc.TaxGroupNo
				Where tg.GroupCode = 'PAFBEF'
			   And GST.SalesReturnNo = SRM.SalesReturnNo
			   For Xml Path ('')),1,1,'') as [PCKFWDRate]
			 ,ISNULL(PCKFWD.TotalValue,0) [PCKFWDValue]
,CONVERT(Bit,0) IsCreateDC,FI.[Freight Invoice No.],FI.[Freight Invoice Date],FI.FreightPayableAmount	
, stuff((Select ',' + GSS.GSTRSectionName from Finance.VoucherGSTDetail VGD 
	inner join GlobalData.GSTRSection GSS on GSS.GSTRSectionNo = vgd.GSTRSectionNo 
	where SRM.SalesReturnNo = VGD.DocumentNo and VGD.FormCode like 'SDSR' 
	Group by GSS.GSTRSectionName
	For xml path('')
	),1,1,'')[GSTR Section]
 From  Sales.SalesReturnMain  SRM
	Inner Join masterdata.mVendorLocationDetail VL on VL.VendorLocationNo = SRM.CustomerLocationNo
	Inner Join masterdata.mVendorLocationInformation VLI on VLI.VendorLocationNo=VL.VendorLocationNo
	LEft Join GlobalData.GSTRegistrationType RT on RT.GSTRegistrationTypeNo=VL.GSTRegistrationTypeNo
	Left Join MAsterdata.mStateMaster ST on ST.StateNo=VL.StateNo
	Inner Join masterdata.mCompanymaster CM on CM.CompanyNo= SRM.CompanyNo
	Inner Join #TempSRComp CT on CT.CompanyNo=SRM.CompanyNo
	Left Join (
				Select DD.RefDocNo,DD.PayableAmount [FreightPayableAmount]
				,FIM.DocumentNoYearly [Freight Invoice No.]
				,FIM.DocumentDate [Freight Invoice Date]
				From Finance.FreightInvoiceDocumentDetail DD
				Inner Join Finance.FreightInvoiceMain FIM on FIM.FreightInvoiceNo=DD.FreightInvoiceNo
				Where FIM.FreightDocumentNo=10
			  )FI on FI.RefDocNo = SRM.SalesReturnNo	
	Inner join  ( Select ID.SAlesReturnNo ,Sum(NetAmount) as NetAmount,ID.CommercialInvoiceNo
					From Sales.SalesReturnItemDetail ID 
					Where ID.CommercialInvoiceNo  is not null
					Group By ID.SalesReturnNo ,ID.CommercialInvoiceNo 
	               )ID on ID.SalesReturnNo = SRM.SalesReturnNo
	Left Join (
	            Select BED.SalesReturnNo ,-1 * sum(BED.TotalValue) TotalValue
				From Sales.SalesReturnTaxDetail  BED 
				      Inner Join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo
				Where mc.TaxGroupNo = 3 ----BED
				Group By  BED.SalesReturnNo 
			  ) BED on BED.SAlesReturnNO=SRM.SalesReturnNo
	Left Join (
	            Select BED.SalesReturnNo ,-1 * sum(BED.TotalValue) TotalValue
				From Sales.SalesReturnTaxDetail  BED 
				     Inner Join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo
				Where mc.TaxGroupNo = 4---EDU
				Group By  BED.SalesReturnNo 
			  ) EDU on EDU.SalesReturnNo = SRM.SalesReturnNo
	Left Join (
	            Select BED.SalesReturnNo ,-1 * sum(BED.TotalValue) TotalValue
				from Sales.SalesReturnTaxDetail   BED 
				inner join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo
				where mc.TaxGroupNo = 5
				group by  BED.SalesReturnNo 
				) SHE on SHE.SalesReturnNo = SRM.SalesReturnNo 	
	Left Join (Select BED.SalesReturnNo  , sum(BED.TotalValue) TotalValue
				from Sales.SalesReturnTaxDetail BED 
				inner join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo
				where mc.TaxGroupNo = 18
				group by  BED.SalesReturnNo
				) DISC on DISC.SalesReturnNo=SRM.SalesReturnNo									
	Left Join (Select CST.SalesReturnNo  ,MiscChargeName, mc.Rate CSTRate,-1 * CST.TotalValue TotalValue
				from Sales.SalesReturnTaxDetail CST 
				inner join masterdata.mMiscCharges mc on CST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 11
				) CST on CST.SalesReturnNo = SRM.SalesReturnNo
	Left JOin (Select VAT.SalesReturnNo  ,MiscChargeName, mc.Rate VATRate,-1 * VAT.TotalValue TotalValue
				from Sales.SalesReturnTaxDetail VAT 
				inner join masterdata.mMiscCharges mc on VAT.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 12
				) VAT on VAT.SalesReturnNo = SRM.SalesReturnNo
	Left JOin (Select GST.SalesReturnNo  ,-1 * Sum(GST.TotalValue) TotalValue
				from Sales.SalesReturnTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 34
				group by  GST.SalesReturnNo
				) CGST on CGST.SalesReturnNo=SRM.SalesReturnNo
	Left JOin (Select GST.SalesReturnNo  ,-1 * Sum(GST.TotalValue) TotalValue
				from Sales.SalesReturnTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 35
				group by  GST.SalesReturnNo
				) SGST on SGST.SalesReturnNo=SRM.SalesReturnNo
	Left JOin (Select GST.SalesReturnNo  ,-1 * Sum(GST.TotalValue) TotalValue
				from Sales.SalesReturnTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 36
				group by  GST.SalesReturnNo
				) IGST on IGST.SalesReturnNo=SRM.SalesReturnNo
	Left JOin (Select GST.SalesReturnNo  ,-1 * Sum(GST.TotalValue) TotalValue
				from Sales.SalesReturnTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 37
				group by  GST.SalesReturnNo
				) UGST on UGST.SalesReturnNo=SRM.SalesReturnNo
	Left JOin (Select GST.SalesReturnNo  ,-1 * Sum(GST.TotalValue) TotalValue
				from Sales.SalesReturnTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 38
				group by  GST.SalesReturnNo
				) GSTCess on GSTCess.SalesReturnNo=SRM.SalesReturnNo
	Left JOin (Select GST.SalesReturnNo  ,-1 * Sum(GST.TotalValue) TotalValue
				from Sales.SalesReturnTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 14
				group by  GST.SalesReturnNo
				) TCS on TCS.SalesReturnNo=SRm.SalesReturnNo
	Left JOin (Select GST.SalesReturnNo  ,- 1 * Sum(GST.TotalValue) TotalValue
				from Sales.SalesReturnTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 39
				group by  GST.SalesReturnNo
				) INSU on INSU.SalesReturnNo=SRM.SalesReturnNo				
	Left JOin ( Select GST.SalesReturnNo  ,- 1 * Sum(GST.TotalValue) TotalValue
				from Sales.SalesReturnTaxDetail GST 
				Inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo
				Inner Join masterdata.mTaxGroup tg on tg.TaxGroupNo = mc.TaxGroupNo
				Where tg.GroupCode = 'PAFBEF'
				group by  GST.SalesReturnNo
			) PCKFWD on PCKFWD.SalesReturnNo=SRM.SalesReturnNo				
	Inner Join Finance.accVoucherMain VM on VM.VoucherNo=SRM.VoucherNo
	Inner Join masterdata.mFBTaxBookDetail FT on FT.FBNo=VM.FBNo
	Inner Join #TaxBook TB on TB.TaxBookNo=FT.TaxBookNo		
	Inner Join [GlobalData].[SalesReturnSourceDocument] SRDOC on SRDOC.SalesReturnSourceNo = SRM.SalesReturnSourceNo
	Inner Join [GlobalData].[FreightType] FRTPE on FRTPE.FreightTypeNo = SRM.FreightTypeNo
Where SRM.DocumentDate Between @FromDate And @ToDate
		And SRM.CustomerLocationNo = ISNULL(@CustomerLocationNo,SRM.CustomerLocationNo)
		And ID.CommercialInvoiceNo	 is  not null
And ISNULL(@InvoiceType,2)=2		
Union All
---E1
Select 3 as [Type]
		,CI.CommercialInvoiceNo
		,CI.CompanyNo
		,CMR.CompanyName
		,CI.DocumentNoYearly
		,CI.DocumentDate
		,VM.DocumentNoYearly as VoucherNo
		,VM.DocumentDate as VoucherDate
		,'E-1' as InvoiceType
		,'E-1' as [salesCategory]
		,isnull(Stuff((Select distinct ','+ '[' +convert(varchar,AM.DocumentNoYearly) +']' 
					 + '['+convert(varchar(50),AM.DocumentDate,103) +']'
				 From Sales.SalesOrderAmendmentMain AM 
				 Inner Join Sales.CommercialInvoiceItemDetails ID on ID.SalesOrderAmendmentNo=AM.SalesOrderAmendmentNo
				  where id.CommercialInvoiceNo=CI.CommercialInvoiceNo 
				  --order by AM.DocumentDate,AM.DocumentNoYearly 
				  for XML path('') ),1,1,''),CI.RefNoDate) as [RefNo/Date]
		,VL.VendorName [Party Name] 
		,VL.FullAddress
		,VLI.TINNo as PartyTinNo
		,VL.GSTINNo
		,ST.StateName
		,ST.GSTStateCode
		,RT.RegistrationType [GSTRegistrationType]
		,Stuff((Select ','+ HS.HSNSACCode
				 From Sales.CommercialInvoiceItemDetails ID				 
				 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
				 Inner Join Globaldata.HSNSACCode HS on HS.HSNSACCodeNo=IM.HSNSACCodeNo
				 where id.CommercialInvoiceNo=CI.CommercialInvoiceNo 
				 Group by HS.HSNSACCode
				  for XML path('') ),1,1,'') HSNSACCode		                            
		,Stuff((Select ','+ IM.ItemDescription
				 From Sales.CommercialInvoiceItemDetails ID
				 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
				  where id.CommercialInvoiceNo=CI.CommercialInvoiceNo 
				  Group by IM.ItemDescription
				  for XML path('') ),1,1,'') ItemDescription
,Stuff((Select ','+ UM.Alias
		 From Sales.CommercialInvoiceItemDetails ID
		 Inner Join masterdata.mUnitMaster UM on UM.UnitNo=ID.unitNo				 
		  where id.CommercialInvoiceNo=CI.CommercialInvoiceNo 
		  Group by UM.Alias
		  for XML path('') ),1,1,'') Unit  				  
		,(Select SUM(ID.BasicAmount)
				 From Sales.CommercialInvoiceItemDetails ID
				  where id.CommercialInvoiceNo=CI.CommercialInvoiceNo
				  Group By ID.CommercialInvoiceNo 
		  )-ISNULL(DISC.TotalValue,0) as BasicAmt
		,CI.NetAmount
		,CI.LRNo LRNo
		,CI.LRDate as LRDate
		,isnull(BED.TotalValue,0)+isnull(EDU.TotalValue,0)+isnull(SHE.TotalValue,0) as ExciseAmount
		,isnull(BED.TotalValue,0) BEDValue
		,isnull(EDU.TotalValue,0) EDUValue
		,isnull(SHE.TotalValue,0) SHEValue
		,isnull(CST.MiscChargeName,VAT.MiscChargeName) VATCSTRate
		,isnull(CST.TotalValue,VAT.TotalValue) as VATCSTAmt
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.CommercialInvoiceTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 34
			   And GST.CommercialInvoiceNo = CI.CommercialInvoiceNo
			   For Xml Path ('')),1,1,'') as CGSTRate	
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.CommercialInvoiceTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 35
			   And GST.CommercialInvoiceNo = CI.CommercialInvoiceNo
			   For Xml Path ('')),1,1,'') as SGSTRate	
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.CommercialInvoiceTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 36
			   And GST.CommercialInvoiceNo = CI.CommercialInvoiceNo
			   For Xml Path ('')),1,1,'') as IGSTRate	
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.CommercialInvoiceTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 37
			   And GST.CommercialInvoiceNo = CI.CommercialInvoiceNo
			   For Xml Path ('')),1,1,'') as UGSTRate	
		,isnull(CGST.TotalValue,0) CGSTValue
		,isnull(SGST.TotalValue,0) SGSTValue
		,isnull(IGST.TotalValue,0) IGSTValue
		,isnull(UGST.TotalValue,0) UGSTValue
		,isnull(GSTCess.TotalValue,0) GSTCessValue
		,isnull(TCS.TotalValue,0) TCSValue
		,isnull(INSU.TotalValue,0) TransitInsuranceValue		
		,CI.NetAmount-(isnull(BED.TotalValue,0)+isnull(EDU.TotalValue,0)+isnull(SHE.TotalValue,0)+coalesce(CST.TotalValue,VAT.TotalValue,0)
		+ isnull(CGST.TotalValue,0) + isnull(SGST.TotalValue,0) + isnull(IGST.TotalValue,0) + isnull(UGST.TotalValue,0) + isnull(GSTCess.TotalValue,0) 
		+
							   ((Select SUM(ID.BasicAmount) 
								 From Sales.CommercialInvoiceItemDetails ID
								 Where id.CommercialInvoiceNo=CI.CommercialInvoiceNo
								 Group By ID.CommercialInvoiceNo 
								 )-ISNULL(DISC.TotalValue,0)
								)
		+ ISNULL(TCS.TotalValue,0) + ISNULL(INSU.TotalValue,0) + ISNULL(PCKFWD.TotalValue,0)							
				  ) [OtherCharges]
		,Stuff((select  distinct ','+  aM.AccountName 
									from Finance.accVoucherDetail VD
									--Inner Join Finance.ARDItemRule IR on IR.AccountNo=VD.AccountNo
									Inner Join masterdata.mAccountMaster aM on aM.AccountNo=vd.AccountNo
									Inner Join masterdata.mAccountGroup AG on AG.GroupNo=aM.DefaultGroupNo
									Where VD.VoucherNo=CI.VoucherNo
									And AG.GroupTypeNo=13
									Group by aM.AccountName
									For Xml path('')				
									--Having COUNT(am.accountNAme)=1
								),1,1,'') as  StockAcc
		,(
		  Select case when COUNT(distinct UnitNo)>1 then CONVERT(Decimal(15,3),Null) else SUM(Quantity) end 
		  From Sales.CommercialInvoiceItemDetails
		  Where CommercialInvoiceNo=CI.CommercialInvoiceNo
		  group by CommercialInvoiceNo	
		)	[Quantity]	
		,(
		  Select case when COUNT(ItemNo)=1 then convert(varchar,Convert(decimal(18,2),sum(Rate) * CI.MultiplicativeRate*CI.DivisibilityRate) ) else '' end 
		  From Sales.CommercialInvoiceItemDetails
		  Where CommercialInvoiceNo=CI.CommercialInvoiceNo
		  group by CommercialInvoiceNo
		) [Rate]
		,Stuff((Select distinct ','+'[' + ISNULL(PB.DocumentNoYearly,GR.DocumentNoYearly) 
                 +',Dt-'+convert(varchar(50),isnull(PB.DocumentDate,GR.DocumentDate),103) +']' 
				From Sales.CommercialInvoiceReferenceDetail iild
				Left Join Finance.PurchaseBillMain PB on PB.PurchaseBillNo=iild.PurchaseBillNo
				Left Join Inventory.GRNMain GR on GR.GRNNo=iild.MRANo	
				Where iild.CommercialInvoiceNo=CI.CommercialInvoiceNo
				For Xml Path('')),1,1,'')	VendorInvoiceNo,
		CI.WayBillNo,CI.WayBillDate,CI.IRN,CI.AckNo,CI.AckDate 
		--,(
		--		   Select SUM(ERGP1.Qty)
		--				From sales.InvoiceItemLotDetail iild
		--				left join inventory.invlotsummary ils on iild.InvLotSummaryNo = ils.InvLotSummaryNo
		--					LEFT join Inventory.InvlotSummaryRefDetail lsrd on lsrd.InvLotSummaryNo = ils.InvLotSummaryNo
		--				left JOIN Finance.ExciseRGPart ERGP1 on ERGP1.ExciseRGPartNo = lsrd .ExciseRGPartNo 
		--				left join Finance.ExciseRGPart ERGP on ERGP.ExciseRGPartNo = ERGP1.RefExciseRGPartNo	
		--				Where iild.InvoiceNo=CI.CommercialInvoiceNo
		--		 ) VendorInvoiceQty
		--		 ,(
		--		   Select SUM(ERGP1.AssessableAmount)
		--				From sales.InvoiceItemLotDetail iild
		--				left join inventory.invlotsummary ils on iild.InvLotSummaryNo = ils.InvLotSummaryNo
		--					LEFT join Inventory.InvlotSummaryRefDetail lsrd on lsrd.InvLotSummaryNo = ils.InvLotSummaryNo
		--				left JOIN Finance.ExciseRGPart ERGP1 on ERGP1.ExciseRGPartNo = lsrd .ExciseRGPartNo 
		--				left join Finance.ExciseRGPart ERGP on ERGP.ExciseRGPartNo = ERGP1.RefExciseRGPartNo	
		--				Where iild.InvoiceNo=CI.CommercialInvoiceNo
		--		 ) VendorInvoiceAmount
	 --,Stuff((Select ','+VLD.VendorName 
		--	From Sales.CommercialInvoiceReferenceDetail iild
		--	Inner Join  Finance.PurchaseBillMain PB on PB.PurchaseBillNo=iild.PurchaseBillNo
		--	Inner Join masterdata.mVendorLocationDetail VLD ON VLD.VendorLocationNo = PB.VendorLocationNo 
		--	Where iild.CommercialInvoiceNo=CI.CommercialInvoiceNo
		--	For Xml Path('')),1,1,'')	VendorName 
	,CI.MultiplicativeRate*CI.DivisibilityRate [Exchange Rate]
		 ,LEFT(DateName(MONTH,CI.DocumentDate),3)+ '-' + Convert(varchar(4),YEAR(CI.DocumentDate)) [Invoice Month]
		 ,SRDOC.SourceDocument [Source Document]
		 ,FRTPE.FreightType [Freight Type]
		 ,Stuff((Select ','+ GM.GroupName
					 From Sales.CommercialInvoiceItemDetails ID
					 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
					 Inner Join masterdata.mSubGroupMaster SGM on SGM.SubGroupNo = IM.SubGroupNo
					 Inner Join masterdata.mGroupMaster GM on GM.GroupNo = SGM.GroupNo
					  where id.CommercialInvoiceNo= CI.CommercialInvoiceNo
					  Group by GM.GroupName
					  for XML path('') ),1,1,'') [Group Name]
			,Stuff((Select ','+ IT.Type
					 From Sales.CommercialInvoiceItemDetails ID
					 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
					 Inner Join [GlobalData].[ItemType] IT on IT.ItemTypeNo = IM.ItemTypeNo
					  where ID.CommercialInvoiceNo= CI.CommercialInvoiceNo
					  Group by IT.Type
					  for XML path('') ),1,1,'') [Material Type]
			,STUFF((
					Select ','+ SC.SalesCategory
					From Sales.CommercialInvoiceItemDetails CID 
					Inner Join Sales.SalesOrderAmendmentMain SOA on SOA.SalesOrderAmendmentNo = CID.SalesOrderAmendmentNo
					Inner Join GlobalData.SalesCategory SC on SC.SalesCategoryNo = SOA.SalesCategoryNo
					Where CID.CommercialInvoiceNo = CI.CommercialInvoiceNo
					Group by SC.SalesCategory
					FOR XML PATH('')
		           ),1,1,'') [Invoice Category]
		   ,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			    from Sales.CommercialInvoiceTaxDetail GST
			    Inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo
				Inner Join masterdata.mTaxGroup tg on tg.TaxGroupNo = mc.TaxGroupNo
				Where tg.GroupCode = 'PAFBEF'
			    And GST.CommercialInvoiceNo = CI.CommercialInvoiceNo
			   For Xml Path ('')),1,1,'') as [PCKFWDRate]
			,ISNULL(PCKFWD.TotalValue,0) 	   [PCKFWDValue]
,CONVERT(Bit,0) IsCreateDC,FI.[Freight Invoice No.],FI.[Freight Invoice Date],FI.FreightPayableAmount	
, stuff((Select ',' + GSS.GSTRSectionName from Finance.VoucherGSTDetail VGD 
	inner join GlobalData.GSTRSection GSS on GSS.GSTRSectionNo = vgd.GSTRSectionNo 
	where CI.CommercialInvoiceNo = VGD.DocumentNo and VGD.FormCode like 'SDCI' 
	Group by GSS.GSTRSectionName
	For xml path('')
	),1,1,'')[GSTR Section]
From Sales.CommercialInvoiceMain CI
		Inner Join masterdata.mVendorLocationDetail VL on VL.VendorLocationNo=CI.CustomerLocationNo
		Inner Join masterdata.mVendorLocationInformation VLI on VLI.VendorLocationNo=VL.VendorLocationNo
	LEft Join GlobalData.GSTRegistrationType RT on RT.GSTRegistrationTypeNo=VL.GSTRegistrationTypeNo
	Left Join MAsterdata.mStateMaster ST on ST.StateNo=VL.StateNo
		Inner Join masterdata.mCompanymaster CMR on CMR.CompanyNo=CI.CompanyNo
		Inner Join #TempSRComp CT on CT.CompanyNo=CI.CompanyNo
	Left Join (
				Select DD.RefDocNo,DD.PayableAmount [FreightPayableAmount]
				,FIM.DocumentNoYearly [Freight Invoice No.]
				,FIM.DocumentDate [Freight Invoice Date]
				From Finance.FreightInvoiceDocumentDetail DD
				Inner Join Finance.FreightInvoiceMain FIM on FIM.FreightInvoiceNo=DD.FreightInvoiceNo
				Where FIM.FreightDocumentNo=5
			  )FI on FI.RefDocNo = CI.CommercialInvoiceNo
		Left Join (Select BED.CommercialInvoiceNo  ,sum(BED.TotalValue) TotalValue
					from Sales.CommercialInvoiceTaxDetail BED 
					inner join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo 
					where mc.TaxGroupNo = 3
					group by  BED.CommercialInvoiceNo
					) BED on BED.CommercialInvoiceNo=CI.CommercialInvoiceNo	
		Left Join (Select BED.CommercialInvoiceNo  ,sum(BED.TotalValue) TotalValue
					from Sales.CommercialInvoiceTaxDetail BED 
					inner join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo 
					where mc.TaxGroupNo = 4
					group by  BED.CommercialInvoiceNo
					) EDU on EDU.CommercialInvoiceNo=CI.CommercialInvoiceNo	
		Left Join (Select BED.CommercialInvoiceNo  ,sum(BED.TotalValue) TotalValue
					from Sales.CommercialInvoiceTaxDetail BED 
					inner join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo 
					where mc.TaxGroupNo = 5
					group by  BED.CommercialInvoiceNo
					) SHE on SHE.CommercialInvoiceNo=CI.CommercialInvoiceNo	
		Left Join (Select BED.CommercialInvoiceNo  ,sum(BED.TotalValue) TotalValue
					from Sales.CommercialInvoiceTaxDetail BED 
					inner join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo 
					where mc.TaxGroupNo = 18
					group by  BED.CommercialInvoiceNo
					) DISC on DISC.CommercialInvoiceNo=CI.CommercialInvoiceNo
		Left Join (Select CST.CommercialInvoiceNo  ,MiscChargeName, mc.Rate CSTRate,CST.TotalValue
					from Sales.CommercialInvoiceTaxDetail CST 
					inner join masterdata.mMiscCharges mc on CST.MiscChargeNo = mc.MiscChargeNo 
					where mc.TaxGroupNo = 11
					) CST on CST.CommercialInvoiceNo=CI.CommercialInvoiceNo
		Left JOin (Select VAT.CommercialInvoiceNo  ,MiscChargeName, mc.Rate VATRate,VAT.TotalValue
					from Sales.CommercialInvoiceTaxDetail VAT 
					inner join masterdata.mMiscCharges mc on VAT.MiscChargeNo = mc.MiscChargeNo 
					where mc.TaxGroupNo = 12
					) VAT on VAT.CommercialInvoiceNo=CI.CommercialInvoiceNo
	Left JOin (Select GST.CommercialInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.CommercialInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 34
				group by  GST.CommercialInvoiceNo
				) CGST on CGST.CommercialInvoiceNo=CI.CommercialInvoiceNo
	Left JOin (Select GST.CommercialInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.CommercialInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 35
				group by  GST.CommercialInvoiceNo
				) SGST on SGST.CommercialInvoiceNo=CI.CommercialInvoiceNo
	Left JOin (Select GST.CommercialInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.CommercialInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 36
				group by  GST.CommercialInvoiceNo
				) IGST on IGST.CommercialInvoiceNo=CI.CommercialInvoiceNo
	Left JOin (Select GST.CommercialInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.CommercialInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 37
				group by  GST.CommercialInvoiceNo
				) UGST on UGST.CommercialInvoiceNo=CI.CommercialInvoiceNo
	Left JOin (Select GST.CommercialInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.CommercialInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 38
				group by  GST.CommercialInvoiceNo
				) GSTCess on GSTCess.CommercialInvoiceNo=CI.CommercialInvoiceNo
	Left JOin (Select GST.CommercialInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.CommercialInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 14
				group by  GST.CommercialInvoiceNo
				) TCS on TCS.CommercialInvoiceNo=CI.CommercialInvoiceNo
	Left JOin (Select GST.CommercialInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.CommercialInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 39
				group by  GST.CommercialInvoiceNo
				) INSU on INSU.CommercialInvoiceNo=CI.CommercialInvoiceNo				
	Left JOin ( Select GST.CommercialInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.CommercialInvoiceTaxDetail GST 
				Inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo
				Inner Join masterdata.mTaxGroup tg on tg.TaxGroupNo = mc.TaxGroupNo
				Where tg.GroupCode = 'PAFBEF'
				group by  GST.CommercialInvoiceNo
				) PCKFWD on PCKFWD.CommercialInvoiceNo=CI.CommercialInvoiceNo				
	Inner Join Finance.accVoucherMain VM on VM.VoucherNo=CI.VoucherNo
	Inner Join masterdata.mFBTaxBookDetail FT on FT.FBNo=VM.FBNo
	Inner Join masterdata.mTaxBookMain TB on TB.TaxBookNo=FT.TaxBookNo					
	Inner Join #TaxBook TB1 on TB1.TaxBookNo=FT.TaxBookNo
	Inner Join [GlobalData].[DispatchSourceDocument] SRDOC on SRDOC.DispatchSourceNo = CI.SourceDocumentNo
	Left Join GlobalData.FreightType FRTPE on FRTPE.FreightTypeNo = CI.FreightTypeNo
where CI.SourceDocumentNo in (6,10)

		And CI.DocumentDate Between @FromDate And @ToDate
		And CI.CustomerLocationNo=ISNULL(@CustomerLocationNo,CI.CustomerLocationNo)
		And CI.StatusNo <> 4
		--And isnull(TB.TaxBookNo,0)=Coalesce(@TaxBookNo,TB.TaxBookNo,0)
And ISNULL(@InvoiceType,3)=3


Union All

-- Supplementary Invoice
Select 4 as [Type]
,SI.SupplementaryInvoiceNo
,SI.CompanyNo
,CMR.CompanyName
,SI.DocumentNoYearly
,SI.DocumentDate
,VM.DocumentNoYearly as VoucherNo
,VM.DocumentDate as VoucherDate 
,'Supplementary Invoice' as InvoiceType
,'Supplementary Invoice' as [salesCategory]
,Stuff((Select distinct ','+ '[' +convert(varchar,AM.DocumentNoYearly) +']' 
             + '['+convert(varchar(50),AM.DocumentDate,103) +']'
         From Sales.SalesOrderAmendmentMain AM 
         Inner Join Sales.InvoiceItemDetails IID On IID.SalesOrderAmendmentNo =AM.SalesOrderAmendmentNo
         Inner Join Sales.SalesSupplementaryInvoiceItemDetails ID on ID.InvoiceNo = IID.InvoiceNo  
          where id.SupplementaryInvoiceNo= SI.SupplementaryInvoiceNo 
          --order by AM.DocumentDate,AM.DocumentNoYearly 
          for XML path('') ),1,1,'') as [RefNo/Date]
,VL.VendorName [Party Name] 
,VL.FullAddress
,VLI.TINNo as PartyTinNo
		,VL.GSTINNo
		,ST.StateName
		,ST.GSTStateCode
		,RT.RegistrationType [GSTRegistrationType]
		,Stuff((Select ','+ HS.HSNSACCode
				 From Sales.SalesSupplementaryInvoiceItemDetails ID				 
				 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
				 Inner Join Globaldata.HSNSACCode HS on HS.HSNSACCodeNo=IM.HSNSACCodeNo
				 where id.SupplementaryInvoiceNo=SI.SupplementaryInvoiceNo 
				 Group by HS.HSNSACCode
				  for XML path('') ),1,1,'') HSNSACCode                            
,Stuff((Select ','+ IM.ItemDescription
         From Sales.SalesSupplementaryInvoiceItemDetails ID
         Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
          where id.SupplementaryInvoiceNo=SI.SupplementaryInvoiceNo 
          Group by IM.itemDescription
          for XML path('') ),1,1,'') ItemDescription
,Stuff((Select ','+ UM.Alias
		 From Sales.SalesSupplementaryInvoiceItemDetails ID
		 Inner Join masterdata.mUnitMaster UM on UM.UnitNo=ID.unitNo				 
		  where id.SupplementaryInvoiceNo=SI.SupplementaryInvoiceNo 
		  Group by UM.Alias
		  for XML path('') ),1,1,'') Unit  	          
,(Select SUM(ID.BasicAmount)
         From Sales.SalesSupplementaryInvoiceItemDetails ID
          where id.SupplementaryInvoiceNo=SI.SupplementaryInvoiceNo
          Group By ID.SupplementaryInvoiceNo 
  )-ISNULL(DISC.TotalValue,0) as BasicAmt
,SI.NetAmount
,null LRNo
,null as LRDate
,isnull(BED.TotalValue,0)+isnull(EDU.TotalValue,0)+isnull(SHE.TotalValue,0) as ExSIseAmount
,isnull(BED.TotalValue,0) BEDValue
,isnull(EDU.TotalValue,0) EDUValue
,isnull(SHE.TotalValue,0) SHEValue
,isnull(CST.MiscChargeName,VAT.MiscChargeName) VATCSTRate
,isnull(CST.TotalValue,VAT.TotalValue) as VATCSTAmt
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.SalesSupplementaryInvoiceTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 34
			   And GST.SupplementaryInvoiceNo = SI.SupplementaryInvoiceNo
			   For Xml Path ('')),1,1,'') as CGSTRate	
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.SalesSupplementaryInvoiceTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 35
			   And GST.SupplementaryInvoiceNo = SI.SupplementaryInvoiceNo
			   For Xml Path ('')),1,1,'') as SGSTRate	
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.SalesSupplementaryInvoiceTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 36
			   And GST.SupplementaryInvoiceNo = SI.SupplementaryInvoiceNo
			   For Xml Path ('')),1,1,'') as IGSTRate	
		,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.SalesSupplementaryInvoiceTaxDetail GST
			   inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
			   where mc.TaxGroupNo = 37
			   And GST.SupplementaryInvoiceNo = SI.SupplementaryInvoiceNo
			   For Xml Path ('')),1,1,'') as UGSTRate	
		,isnull(CGST.TotalValue,0) CGSTValue
		,isnull(SGST.TotalValue,0) SGSTValue
		,isnull(IGST.TotalValue,0) IGSTValue
		,isnull(UGST.TotalValue,0) UGSTValue
		,isnull(GSTCess.TotalValue,0) GSTCessValue
		,isnull(TCS.TotalValue,0) TCSValue
		,isnull(INSU.TotalValue,0) TransitInsuranceValue			
,SI.NetAmount-(isnull(BED.TotalValue,0)+isnull(EDU.TotalValue,0)+isnull(SHE.TotalValue,0)+coalesce(CST.TotalValue,VAT.TotalValue,0)
+ isnull(CGST.TotalValue,0) + isnull(SGST.TotalValue,0) + isnull(IGST.TotalValue,0) + isnull(UGST.TotalValue,0) + isnull(GSTCess.TotalValue,0) 
+
		               ((Select SUM(ID.BasicAmount) 
                         From Sales.SalesSupplementaryInvoiceItemDetails  ID
                         Where id.SupplementaryInvoiceNo=SI.SupplementaryInvoiceNo
                         Group By ID.SupplementaryInvoiceNo 
                         )-ISNULL(DISC.TotalValue,0)
                        )
		+ ISNULL(TCS.TotalValue,0) + ISNULL(INSU.TotalValue,0) + isnull(PCKFWD.TotalValue,0)                 
		  ) [OtherCharges]
,Stuff((select  distinct ','+  aM.AccountName 
							from Finance.accVoucherDetail VD
							--Inner Join Finance.ARDItemRule IR on IR.AccountNo=VD.AccountNo
							Inner Join masterdata.mAccountMaster aM on aM.AccountNo=vd.AccountNo
							Inner Join masterdata.mAccountGroup AG on AG.GroupNo=aM.DefaultGroupNo
							Where VD.VoucherNo=SI.VoucherNo
							And AG.GroupTypeNo=13
							Group by aM.AccountName
							For Xml path('')				
							--Having COUNT(am.accountNAme)=1
						),1,1,'') as  StockAcc
--,(
--  Select case when COUNT(distinct UnitNo)>1 then '' else convert(varchar,SUM(Quantity)) end 
--  From Sales.SalesSupplementaryInvoiceItemDetails 
--  Where SupplementaryInvoiceNo=SI.SupplementaryInvoiceNo 
--  group by SupplementaryInvoiceNo	
--)	[Quantity]	
,CONVERT(Decimal(15,3), Null) Quantity
,(
  Select case when COUNT(ItemNo)=1 then convert(varchar,Convert(decimal(18,2),sum(SuppInvoiceRate )*SI.MultiplicativeRate*SI.DivisibilityRate)) else '' end 
  From Sales.SalesSupplementaryInvoiceItemDetails 
  Where SupplementaryInvoiceNo=SI.SupplementaryInvoiceNo
  group by SupplementaryInvoiceNo
) [Rate]
,null	VendorInvoiceNo,
CAST(NULL as varchar(30)) [WayBillNo]
,CAST(NULL as smalldatetime) [WayBillDate]	
,CAST(NULL as varchar(100)) IRN
,CAST(Null as varchar(30)) AckNo
,CAST(NULL as smalldatetime) AckDate						
,SI.MultiplicativeRate*SI.DivisibilityRate [Exchange Rate]
,LEFT(DateName(MONTH,SI.DocumentDate),3) +'-'+ Convert(varchar(4),YEAR(SI.DocumentDate)) [Invoice Month]
,SRDOC.SourceDocument [Source Document]
,null [Freight Type]
,Stuff((Select ','+ GM.GroupName
		 From Sales.SalesSupplementaryInvoiceItemDetails ID
		 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
		 Inner Join masterdata.mSubGroupMaster SGM on SGM.SubGroupNo = IM.SubGroupNo
		 Inner Join masterdata.mGroupMaster GM on GM.GroupNo = SGM.GroupNo
		  where id.SupplementaryInvoiceNo= SI.SupplementaryInvoiceNo
		  Group by GM.GroupName
		  for XML path('') ),1,1,'') [Group Name]
,Stuff((Select ','+ IT.Type
		 From Sales.SalesSupplementaryInvoiceItemDetails ID
		 Inner Join masterdata.mItemMaster IM on IM.ItemNo=ID.ItemNo
		 Inner Join [GlobalData].[ItemType] IT on IT.ItemTypeNo = IM.ItemTypeNo
		  where ID.SupplementaryInvoiceNo= SI.SupplementaryInvoiceNo
		  Group by IT.Type
		  for XML path('') ),1,1,'') [Material Type]
 ,ISNULL(STUFF((Select ','+SC.SalesCategory
					From  Sales.SalesSupplementaryInvoiceReferenceDetail REFD
					Inner Join Sales.InvoiceMain IVM on IVM.InvoiceNo =REFD.InvoiceNo   and SI.SourceDocumentNo = 1 -- tax invoice 
					Inner Join GlobalData.SalesCategory SC on SC.SalesCategoryNo=IVM.InvoiceCategoryNo
					Where REFD.SupplementaryInvoiceNo  = SI.SupplementaryInvoiceNo
					for XML path('')),1,1,'')
					,
				STUFF((	Select ','+SC.SalesCategory
				From [Sales].SalesSupplementaryInvoiceReferenceDetail REFD
				Inner Join Sales.CommercialInvoiceItemDetails CIID on CIID.CommercialInvoiceNo = REFD.CommercialInvoiceNo 
				Inner Join Sales.SalesOrderAmendmentMain SOA on SOA.SalesOrderAmendmentNo = CIID.SalesOrderAmendmentNo and SI.SourceDocumentNo = 2 -- commercial invoice
				Inner Join GlobalData.SalesCategory SC on SC.SalesCategoryNo= SOA.SalesCategoryNo 
				Where REFD.SupplementaryInvoiceNo = SI.SupplementaryInvoiceNo
				for XML path('')),1,1,'')
				) [Invoice Category]
			,Stuff((Select ','+ Convert(varchar(50),mc.Rate)
			   from Sales.SalesSupplementaryInvoiceTaxDetail GST
			   Inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo
			   Inner Join masterdata.mTaxGroup tg on tg.TaxGroupNo = mc.TaxGroupNo
			   Where tg.GroupCode = 'PAFBEF'
				And GST.SupplementaryInvoiceNo = SI.SupplementaryInvoiceNo
			   For Xml Path ('')),1,1,'') as [PCKFWDRate]
			,isnull(PCKFWD.TotalValue,0) PCKFWDValue
,convert(Bit,0) IsCreateDC,'' [Freight Invoice No.],CONVERT(SmallDateTime,Null) [Freight Invoice Date],Convert(Money,Null) FreightPayableAmount
, stuff((Select ',' + GSS.GSTRSectionName from Finance.VoucherGSTDetail VGD 
	inner join GlobalData.GSTRSection GSS on GSS.GSTRSectionNo = vgd.GSTRSectionNo 
	where SI.SupplementaryInvoiceNo = VGD.DocumentNo and VGD.FormCode like 'SLTI' 
	Group by GSS.GSTRSectionName
	For xml path('')
	),1,1,'')[GSTR Section]
 From Sales.SalesSupplementaryInvoiceMain SI
Inner Join masterdata.mVendorLocationDetail VL on VL.VendorLocationNo=SI.CustomerLocationNo
Inner Join masterdata.mVendorLocationInformation VLI on VLI.VendorLocationNo=VL.VendorLocationNo
LEft Join GlobalData.GSTRegistrationType RT on RT.GSTRegistrationTypeNo=VL.GSTRegistrationTypeNo
Left Join MAsterdata.mStateMaster ST on ST.StateNo=VL.StateNo
Inner Join masterdata.mCompanymaster CMR on CMR.CompanyNo=SI.CompanyNo
Inner Join #TempSRComp CT on CT.CompanyNo=SI.CompanyNo
Left Join (Select BED.SupplementaryInvoiceNo   ,sum(BED.TotalValue) TotalValue
			from Sales.SalesSupplementaryInvoiceTaxDetail  BED 
			inner join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 3
			group by  BED.SupplementaryInvoiceNo
			) BED on BED.SupplementaryInvoiceNo=SI.SupplementaryInvoiceNo
Left Join (Select BED.SupplementaryInvoiceNo  ,sum(BED.TotalValue) TotalValue
			from Sales.SalesSupplementaryInvoiceTaxDetail   BED 
			inner join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 4
			group by  BED.SupplementaryInvoiceNo
			) EDU on EDU.SupplementaryInvoiceNo=SI.SupplementaryInvoiceNo
Left Join (Select BED.SupplementaryInvoiceNo  ,sum(BED.TotalValue) TotalValue
			from Sales.SalesSupplementaryInvoiceTaxDetail BED 
			inner join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 5
			group by  BED.SupplementaryInvoiceNo
			) SHE on SHE.SupplementaryInvoiceNo = SI.SupplementaryInvoiceNo	
Left Join (Select BED.SupplementaryInvoiceNo ,sum(BED.TotalValue) TotalValue
			from Sales.SalesSupplementaryInvoiceTaxDetail BED 
			inner join masterdata.mMiscCharges mc on BED.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 18
			group by  BED.SupplementaryInvoiceNo
			) DISC on DISC.SupplementaryInvoiceNo=SI .SupplementaryInvoiceNo
Left Join (Select CST.SupplementaryInvoiceNo  ,MiscChargeName, mc.Rate CSTRate,CST.TotalValue
			from Sales.SalesSupplementaryInvoiceTaxDetail CST 
			inner join masterdata.mMiscCharges mc on CST.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 11
			) CST on CST.SupplementaryInvoiceNo= SI.SupplementaryInvoiceNo
Left JOin (Select VAT.SupplementaryInvoiceNo,MiscChargeName, mc.Rate VATRate,VAT.TotalValue
			from Sales.SalesSupplementaryInvoiceTaxDetail VAT 
			inner join masterdata.mMiscCharges mc on VAT.MiscChargeNo = mc.MiscChargeNo 
			where mc.TaxGroupNo = 12
			) VAT on VAT.SupplementaryInvoiceNo = SI.SupplementaryInvoiceNo
	Left JOin (Select GST.SupplementaryInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.SalesSupplementaryInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 34
				group by  GST.SupplementaryInvoiceNo
				) CGST on CGST.SupplementaryInvoiceNo=SI.SupplementaryInvoiceNo
	Left JOin (Select GST.SupplementaryInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.SalesSupplementaryInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 35
				group by  GST.SupplementaryInvoiceNo
				) SGST on SGST.SupplementaryInvoiceNo=SI.SupplementaryInvoiceNo
	Left JOin (Select GST.SupplementaryInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.SalesSupplementaryInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 36
				group by  GST.SupplementaryInvoiceNo
				) IGST on IGST.SupplementaryInvoiceNo=SI.SupplementaryInvoiceNo
	Left JOin (Select GST.SupplementaryInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.SalesSupplementaryInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 37
				group by  GST.SupplementaryInvoiceNo
				) UGST on UGST.SupplementaryInvoiceNo=SI.SupplementaryInvoiceNo
	Left JOin (Select GST.SupplementaryInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.SalesSupplementaryInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 38
				group by  GST.SupplementaryInvoiceNo
				) GSTCess on GSTCess.SupplementaryInvoiceNo=SI.SupplementaryInvoiceNo
	Left JOin (Select GST.SupplementaryInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.SalesSupplementaryInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 14
				group by  GST.SupplementaryInvoiceNo
				) TCS on TCS.SupplementaryInvoiceNo=SI.SupplementaryInvoiceNo
	Left JOin (Select GST.SupplementaryInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.SalesSupplementaryInvoiceTaxDetail GST 
				inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo 
				where mc.TaxGroupNo = 39
				group by  GST.SupplementaryInvoiceNo
				) INSU on INSU.SupplementaryInvoiceNo=SI.SupplementaryInvoiceNo											
	Left JOin (Select GST.SupplementaryInvoiceNo  ,Sum(GST.TotalValue) TotalValue
				from Sales.SalesSupplementaryInvoiceTaxDetail GST 
				Inner join masterdata.mMiscCharges mc on GST.MiscChargeNo = mc.MiscChargeNo
				Inner Join masterdata.mTaxGroup tg on tg.TaxGroupNo = mc.TaxGroupNo
				Where tg.GroupCode = 'PAFBEF'
				group by  GST.SupplementaryInvoiceNo
				) PCKFWD on PCKFWD.SupplementaryInvoiceNo=SI.SupplementaryInvoiceNo	
Inner Join Finance.accVoucherMain VM on VM.VoucherNo = SI.VoucherNo
Inner Join masterdata.mFBTaxBookDetail FT on FT.FBNo=VM.FBNo
Inner Join #TaxBook TB on TB.TaxBookNo=FT.TaxBookNo					
Inner Join GlobalData.SalesSupplementaryInvoiceSourceDocument SRDOC on SRDOC.SourceDocumentNo= SI.SourceDocumentNo
where SI.SourceDocumentNo =1
--and FBNo in (select fbno from masterdata.mFBTaxBookDetail where TaxBookNo = isnull(@TaxBookNo,TaxBookNo))
		
		And SI.DocumentDate Between @FromDate And @ToDate
		And SI.CustomerLocationNo=ISNULL(@CustomerLocationNo,SI.CustomerLocationNo)
		And SI.StatusNo <> 4 
		--And isnull(TB.TaxBookNo,0)=Coalesce(@TaxBookNo,TB.TaxBookNo,0)	
And ISNULL(@InvoiceType,4)=4
) tt

Where tt.Type=ISNULL(@InvoiceType,tt.Type)
Order By DocumentDate,DocumentNoYearly

Drop Table #TaxBook
END

