USE [SpectrumERP]
GO

/****** Object:  StoredProcedure [Purchase].[AI_PurchaseOrderInsight]    Script Date: 15-10-2026 11:21:44 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =======================================================================
-- Author      : Alok
-- Date        : 15/10/2026
-- Description : Purchase Order insight for AI analysis.
--               Returns the complete life-cycle of ONE purchase order as
--               fixed-shape result sets (same count / same columns on every
--               call, empty when nothing exists). Result set 0 is metadata
--               that describes every other result set, the business rules
--               and the execution status, so the caller (AI) can interpret
--               the output without any other documentation.
-- Logic base  : Inventory.MISPOProgressFlowReports (receipt / balance / cancel qty rules)
--               Purchase.vwdpPoitem, Purchase.vwdpPOItemTaxDetail, Purchase.vwdpPOTaxDetail
-- Result sets : 0 Metadata | 1 POHeader | 2 POItem | 3 POItemTax | 4 POTaxSummary
--               5 GateEntry | 6 Receipt (GRN/MRA/SC-BOQ/SIN) | 7 PurchaseBill
--               8 ItemQtySummary | 9 POSummary
-- Exec        : EXEC Purchase.AIPOInsight @PONo = 1234
--               EXEC Purchase.AIPOInsight @PONoYearly = 'PO/0012/24-25', @CompanyNo = 3
-- =======================================================================
 -- Purchase.AI_PurchaseOrderInsight  1644
CREATE PROCEDURE [Purchase].[AI_PurchaseOrderInsight] 
(
     @PONo        int          = NULL   -- internal PO key (Purchase.POMain.PONo)
    ,@PONoYearly  varchar(50)  = NULL   -- PO document number as users see it
    ,@CompanyNo   tinyint      = NULL   -- needed only when @PONoYearly repeats across companies
)
AS
BEGIN
SET NOCOUNT ON;
BEGIN TRY

DECLARE  @TempPONo       int          = @PONo
        ,@Status         varchar(30)  = 'OK'
        ,@StatusMessage  varchar(500) = 'PO found.'
        ,@MatchCount     int
        ,@Today          date         = CONVERT(date, GETDATE());

--------------------------------------------------------------------------
-- Resolve the PO
--------------------------------------------------------------------------
IF @TempPONo IS NULL AND NULLIF(LTRIM(RTRIM(@PONoYearly)),'') IS NOT NULL
BEGIN
    SELECT @MatchCount = COUNT(1), @TempPONo = MAX(PONo)
    FROM Purchase.POMain
    WHERE DocumentNoYearly = @PONoYearly
      AND (@CompanyNo IS NULL OR CompanyNo = @CompanyNo);

    IF @MatchCount > 1
        SELECT @Status        = 'AMBIGUOUS_PO'
              ,@StatusMessage = CONCAT(@MatchCount, ' POs found with number ', @PONoYearly, '. Pass @CompanyNo or @PONo.')
              ,@TempPONo      = NULL;
END

IF @TempPONo IS NULL
   OR NOT EXISTS (SELECT 1 FROM Purchase.POMain WHERE PONo = @TempPONo AND (@CompanyNo IS NULL OR CompanyNo = @CompanyNo))
BEGIN
    IF @Status = 'OK'
        SELECT @Status        = 'PO_NOT_FOUND'
              ,@StatusMessage = CONCAT('No PO found for @PONo=', @PONo, ', @PONoYearly=', @PONoYearly, ', @CompanyNo=', @CompanyNo, '.');
    SET @TempPONo = -1;   -- keeps every result set empty but with the same shape
END

--------------------------------------------------------------------------
-- #POItem : PO lines with discount, qty setting and schedule
--------------------------------------------------------------------------
CREATE TABLE #POItem
(
     POItemDetailNo     int
    ,ItemNo             int
    ,MakeNo             int
    ,TechnicalGradeNo   int
    ,ItemTypeNo         int
    ,StatusNo           int
    ,UnitNo             int
    ,Quantity           decimal(18,3)
    ,Rate               decimal(18,4)
    ,DiscountAmount     decimal(18,2)
    ,BasicValue         decimal(18,2)   -- Qty * Rate - Discount
    ,RateAfterDiscount  decimal(18,4)
    ,NetAmount          decimal(18,2)
    ,POBalancedQty      tinyint
    ,MinScheduleDate    date
    ,MaxScheduleDate    date
);

INSERT INTO #POItem
SELECT POID.POItemDetailNo
      ,POID.ItemNo
      ,ISNULL(POID.MakeNo,0)
      ,ISNULL(POID.TechnicalGradeNo,0)
      ,IM.ItemTypeNo
      ,POID.StatusNo
      ,POID.UnitNo
      ,POID.Quantity
      ,POID.Rate
      ,ISNULL(D.DiscountAmount,0)
      ,CONVERT(decimal(18,2), POID.Quantity * POID.Rate) - ISNULL(D.DiscountAmount,0)
      ,(CONVERT(decimal(18,2), POID.Quantity * POID.Rate) - ISNULL(D.DiscountAmount,0)) / NULLIF(POID.Quantity,0)
      ,POID.NetAmount
      ,PQS.POBalancedQty
      ,SD.MinScheduleDate
      ,SD.MaxScheduleDate
FROM Purchase.POMain PM
INNER JOIN Purchase.POItemDetail POID ON POID.PONo = PM.PONo
INNER JOIN masterdata.mItemMaster IM ON IM.ItemNo = POID.ItemNo
LEFT JOIN Purchase.POQtySetting PQS ON PQS.ItemTypeNo = IM.ItemTypeNo
                                   AND PQS.CompanyNo = PM.CompanyNo
OUTER APPLY (
              Select SUM(PT.TotalAmount) DiscountAmount
              From Purchase.POItemTaxDetail PT
              Inner Join masterdata.mMiscCharges MC On MC.MiscChargeNo = PT.MiscChargeNo
              Where PT.PONo = POID.PONo
                And PT.ItemNo = POID.ItemNo
                And ISNULL(PT.MakeNo,0) = ISNULL(POID.MakeNo,0)
                And ISNULL(PT.TechnicalGradeNo,0) = ISNULL(POID.TechnicalGradeNo,0)
                And MC.TaxGroupNo = 18 -- Discount
            ) D
OUTER APPLY (
              Select MIN(S.ScheduleDate) MinScheduleDate, MAX(S.ScheduleDate) MaxScheduleDate
              From Purchase.POItemScheduleDetail S
              Where S.PONo = POID.PONo
                And S.ItemNo = POID.ItemNo
                And ISNULL(S.MakeNo,0) = ISNULL(POID.MakeNo,0)
                And ISNULL(S.TechnicalGradeNo,0) = ISNULL(POID.TechnicalGradeNo,0)
            ) SD
WHERE PM.PONo = @TempPONo;

--------------------------------------------------------------------------
-- #GE : Gate entry lines against this PO (keyed on the PO line)
--------------------------------------------------------------------------
CREATE TABLE #GE
(
     FlowType          varchar(20)
    ,GateEntryNo       int
    ,GateEntryDate     date
    ,POAmendmentNo     int
    ,ItemNo            int
    ,MakeNo            int
    ,TechnicalGradeNo  int
    ,RcvMakeNo         int
    ,ChallanQty        decimal(18,3)
);

INSERT INTO #GE
-- Standard purchase gate entry
SELECT 'Standard'
      ,GEM.GateEntryNo
      ,GEM.DocumentDate
      ,POID.POAmendmentNo
      ,POID.ItemNo
      ,ISNULL(POID.MakeNo,0)
      ,ISNULL(POID.TechnicalGradeNo,0)
      ,ISNULL(GEID.MakeNo,0)
      ,ISNULL(GEID.ChallanQty,0)
FROM GateEntry.InvGateEntryMain GEM
INNER JOIN GateEntry.InvGateEntryItemDetail GEID ON GEID.GateEntryNo = GEM.GateEntryNo
INNER JOIN Purchase.POAmendmentItemDetail POID ON POID.POAmendmentNo = GEID.POAmendmentNo
                                              AND POID.ItemNo = GEID.ItemNo
                                              AND ISNULL(POID.MakeNo,0) = ISNULL(GEID.MakeNo,0)
                                              AND ISNULL(POID.TechnicalGradeNo,0) = ISNULL(GEID.TechnicalGradeNo,0)
INNER JOIN Purchase.POAmendmentMain POAM ON POAM.POAmendmentNo = POID.POAmendmentNo
WHERE GEM.GateEntrySourceNo = 2
  AND GEM.ModuleNo = 2
  AND POAM.PONo = @TempPONo
UNION ALL
-- Discrete RM gate entry
SELECT 'DiscreteRM'
      ,GEM.GateEntryNo
      ,GEM.DocumentDate
      ,POID.POAmendmentNo
      ,POID.ItemNo
      ,ISNULL(POID.MakeNo,0)
      ,ISNULL(POID.TechnicalGradeNo,0)
      ,ISNULL(GEID.MakeNo,0)
      ,ISNULL(GEID.ChallanQty,0)
FROM GateEntry.InvGateEntryMain GEM
INNER JOIN GateEntry.InvGateEntryItemDetail GEID ON GEID.GateEntryNo = GEM.GateEntryNo
INNER JOIN GateEntry.InvGateEntryOrderDetail OD ON OD.GateEntryNo = GEID.GateEntryNo
INNER JOIN Purchase.POAmendmentItemDetail POID ON POID.POAmendmentNo = OD.POAmendmentNo
                                              AND POID.ItemNo = GEID.ItemNo
                                              AND (POID.MakeNo = GEID.MakeNo OR POID.MakeNo IS NULL)
                                              AND ISNULL(POID.TechnicalGradeNo,0) = ISNULL(GEID.TechnicalGradeNo,0)
INNER JOIN Purchase.POAmendmentMain POAM ON POAM.POAmendmentNo = POID.POAmendmentNo
WHERE GEM.GateEntrySourceNo = 2
  AND GEM.ModuleNo = 19
  AND POAM.PONo = @TempPONo;

--------------------------------------------------------------------------
-- #Rcpt : Receipt lines (GRN incl. MRA, SC-BOQ GRN, Discrete RM SIN)
--         ItemNo/MakeNo/TechnicalGradeNo = PO line key
--         Rcv*                           = item actually received
--------------------------------------------------------------------------
CREATE TABLE #Rcpt
(
     RowId                int IDENTITY(1,1)
    ,FlowType             varchar(20)     -- GRN | GRN-BOQ | SIN
    ,DocNo                int             -- GRNNo / SINNo
    ,DocLineNo            int NULL        -- GRNItemDetailNo
    ,DocNoYearly          nvarchar(100)
    ,DocDate              date
    ,SourceNo             int NULL        -- GRNSourceNo
    ,VendorBillNo         nvarchar(100) NULL
    ,VendorBillDate       date NULL
    ,IsAuthorized         bit
    ,AuthorizedDate       datetime NULL
    ,GateEntryNo          int NULL
    ,POAmendmentNo        int
    ,ItemNo               int
    ,MakeNo               int
    ,TechnicalGradeNo     int NULL        -- NULL for SIN (not tracked there)
    ,RcvItemNo            int
    ,RcvMakeNo            int
    ,RcvTechnicalGradeNo  int NULL
    ,ChallanQty           decimal(18,3)
    ,ReceivedQty          decimal(18,3)
    ,AcceptedQty          decimal(18,3)
    ,RejectedQty          decimal(18,3)
    ,Rate                 decimal(18,4) NULL
    ,WareHouseNo          int NULL
);

INSERT INTO #Rcpt (FlowType, DocNo, DocLineNo, DocNoYearly, DocDate, SourceNo, VendorBillNo, VendorBillDate, IsAuthorized, AuthorizedDate
                  ,GateEntryNo, POAmendmentNo, ItemNo, MakeNo, TechnicalGradeNo, RcvItemNo, RcvMakeNo, RcvTechnicalGradeNo
                  ,ChallanQty, ReceivedQty, AcceptedQty, RejectedQty, Rate, WareHouseNo)
SELECT CASE WHEN BOQ.IsBOQ = 1 THEN 'GRN-BOQ' ELSE 'GRN' END
      ,GRNM.GRNNo
      ,GRID.GRNItemDetailNo
      ,GRNM.DocumentNoYearly
      ,GRNM.DocumentDate
      ,GRNM.GRNSourceNo
      ,GRNM.VendorBillNo
      ,GRNM.VendorBillDate
      ,CASE WHEN ISNULL(GRNM.AuthorizedBy,0) > 0 THEN 1 ELSE 0 END
      ,GRNM.AuthorizedDate
      ,GRID.GateEntryNo
      ,GRID.POAmendmentNo
      ,CASE WHEN BOQ.IsBOQ = 1 THEN GRID.POItemNo                       ELSE GRID.ItemNo                       END
      ,CASE WHEN BOQ.IsBOQ = 1 THEN ISNULL(GRID.POMakeNo,0)             ELSE ISNULL(GRID.MakeNo,0)             END
      ,CASE WHEN BOQ.IsBOQ = 1 THEN ISNULL(GRID.POTechnicalGradeNo,0)   ELSE ISNULL(GRID.TechnicalGradeNo,0)   END
      ,GRID.ItemNo
      ,ISNULL(GRID.MakeNo,0)
      ,ISNULL(GRID.TechnicalGradeNo,0)
      ,ISNULL(GRID.ChallanQty,0)
      ,ISNULL(GRID.ReceivedQty,0)
      ,ISNULL(GRID.AcceptedQty,0)
      ,ISNULL(GRID.RejectedQty,0)
      ,GRID.Rate
      ,GRID.WareHouseNo
FROM Inventory.GRNItemDetail GRID
INNER JOIN Inventory.GRNMain GRNM ON GRNM.GRNNo = GRID.GRNNo
INNER JOIN Purchase.POAmendmentMain POAM ON POAM.POAmendmentNo = GRID.POAmendmentNo
CROSS APPLY (
              Select CASE WHEN GRID.POItemNo IS NOT NULL
                           And (   GRID.POItemNo <> GRID.ItemNo
                                Or ISNULL(GRID.POMakeNo,0) <> ISNULL(GRID.MakeNo,0)
                                Or ISNULL(GRID.POTechnicalGradeNo,0) <> ISNULL(GRID.TechnicalGradeNo,0))
                          THEN 1 ELSE 0 END IsBOQ
            ) BOQ
WHERE POAM.PONo = @TempPONo
  AND (   ISNULL(POAM.IsTransportationRouteApplicable,0) = 0
       OR (BOQ.IsBOQ = 0 AND GRID.RouteIdentity % 0.1 = 0) ); -- route POs: only the final leg counts

INSERT INTO #Rcpt (FlowType, DocNo, DocLineNo, DocNoYearly, DocDate, SourceNo, VendorBillNo, VendorBillDate, IsAuthorized, AuthorizedDate
                  ,GateEntryNo, POAmendmentNo, ItemNo, MakeNo, TechnicalGradeNo, RcvItemNo, RcvMakeNo, RcvTechnicalGradeNo
                  ,ChallanQty, ReceivedQty, AcceptedQty, RejectedQty, Rate, WareHouseNo)
SELECT 'SIN'
      ,SM.SINNo
      ,NULL
      ,SM.DocumentNoYearly
      ,SM.DocumentDate
      ,NULL
      ,SM.VendorBillNo
      ,SM.VendorBillDate
      ,CASE WHEN ISNULL(SM.AuthorizedBy,0) > 0 THEN 1 ELSE 0 END
      ,SM.AuthorizedDate
      ,DSID.GateEntryNo
      ,DSID.POAmendmentNo
      ,DSID.ItemNo
      ,ISNULL(DSID.MakeNo,0)
      ,NULL
      ,DSID.ItemNo
      ,ISNULL(DSID.MakeNo,0)
      ,NULL
      ,ISNULL(DSID.ChallanQty,0)
      ,ISNULL(DSID.ReceivedQty,0)
      ,ISNULL(DSID.AcceptedQty,0)
      ,ISNULL(DSID.RejectedQty,0)
      ,NULL
      ,DSID.WareHouseNo
FROM DiscreteRM.SINItemDetail DSID
INNER JOIN DiscreteRM.SINMain SM ON SM.SINNo = DSID.SINNo
INNER JOIN Purchase.POAmendmentMain POAM ON POAM.POAmendmentNo = DSID.POAmendmentNo
WHERE POAM.PONo = @TempPONo;

--------------------------------------------------------------------------
-- #Bill : Purchase bill lines linked to the receipt lines above
--------------------------------------------------------------------------
CREATE TABLE #Bill
(
     PurchaseBillNo  int
    ,RcptRowId       int
    ,BasicAmount     decimal(18,2)
);

INSERT INTO #Bill
SELECT PBI.PurchaseBillNo, R.RowId, PBI.BasicAmount
FROM Finance.PurchaseBillItemDetail PBI
INNER JOIN #Rcpt R ON R.FlowType IN ('GRN','GRN-BOQ')
                  AND R.DocNo = PBI.GRNNo
                  AND R.RcvItemNo = PBI.ItemNo
                  AND R.RcvMakeNo = ISNULL(PBI.MakeNo,0)
                  AND R.RcvTechnicalGradeNo = ISNULL(PBI.TechnicalGradeNo,0)
UNION ALL
SELECT PBI.PurchaseBillNo, R.RowId, PBI.BasicAmount
FROM Finance.PurchaseBillItemDetail PBI
INNER JOIN #Rcpt R ON R.FlowType = 'SIN'
                  AND R.DocNo = PBI.SINNo
                  AND R.RcvItemNo = PBI.ItemNo
                  AND R.RcvMakeNo = ISNULL(PBI.MakeNo,0);

SELECT PB.PurchaseBillNo
      ,PB.DocumentNoYearly
      ,PB.DocumentDate
      ,PB.VendorBillNo
      ,PB.VendorBillDate
      ,PB.NetAmount
      ,PB.PaymentModeNo
      ,PB.AuthorizedDate
      ,ISNULL(OS.OutstandingAmount,0) OutstandingAmount
INTO #BillHead
FROM Finance.PurchaseBillMain PB
OUTER APPLY (
              Select SUM(ABS(RM.BalanceAmount)) OutstandingAmount
              From Finance.accVoucherDetail AVD
              Inner Join Finance.ARDVendorLocationRule ALD On ALD.AccountNo = AVD.AccountNo
                                                          And ALD.VendorLocationNo = PB.VendorLocationNo
              Inner Join masterdata.mAccountMaster AM On AM.AccountNo = ALD.AccountNo And AM.AccountTypeNo = 4
              Inner Join Finance.ReferenceMain RM On RM.VoucherDetailNo = AVD.VoucherDetailNo
                                                 And RM.AccountNo = ALD.AccountNo
              Where AVD.VoucherNo = PB.VoucherNo
            ) OS
WHERE PB.PurchaseBillNo IN (SELECT PurchaseBillNo FROM #Bill);

--------------------------------------------------------------------------
-- #Cancel : latest cancel / short-close (status 4,7) per PO line
--------------------------------------------------------------------------
SELECT X.ItemNo, X.MakeNo, X.TechnicalGradeNo, X.CancelStatusNo, X.AmendmentQty
INTO #Cancel
FROM (
        Select POID.ItemNo
              ,ISNULL(POID.MakeNo,0)            MakeNo
              ,ISNULL(POID.TechnicalGradeNo,0)  TechnicalGradeNo
              ,PCID.StatusNo                    CancelStatusNo
              ,POID.Quantity                    AmendmentQty
              ,ROW_NUMBER() OVER (PARTITION BY POID.ItemNo, ISNULL(POID.MakeNo,0), ISNULL(POID.TechnicalGradeNo,0)
                                  ORDER BY PCSM.ChangePoStatusNo DESC) RN
        From Purchase.ChangePOStatusMain PCSM
        Inner Join Purchase.ChangePOStatusItemDetails PCID On PCID.ChangePoStatusNo = PCSM.ChangePoStatusNo
                                                          And PCID.StatusNo In (4,7)
        Inner Join Purchase.POAmendmentMain PAM On PAM.POAmendmentNo = PCSM.POAmendmentNo
        Inner Join Purchase.POAmendmentItemDetail POID On POID.POAmendmentNo = PAM.POAmendmentNo
                                                      And POID.ItemNo = PCID.ItemNo
                                                      And ISNULL(POID.MakeNo,0) = ISNULL(PCID.MakeNo,0)
                                                      And ISNULL(POID.TechnicalGradeNo,0) = ISNULL(PCID.TechnicalGradeNo,0)
        Where PAM.PONo = @TempPONo
     ) X
WHERE X.RN = 1;

--------------------------------------------------------------------------
-- #Summary : item-wise quantity roll-up
--------------------------------------------------------------------------
SELECT PI.*
      ,ISNULL(GE.GateEntryQty,0)            GateEntryQty
      ,ISNULL(GE.GateEntryCount,0)          GateEntryCount
      ,GE.FirstGateEntryDate
      ,ISNULL(R.ChallanQty,0)               GRNChallanQty
      ,ISNULL(R.ReceivedQty,0)              GRNReceivedQty
      ,ISNULL(R.AcceptedQty,0)              GRNAcceptedQty
      ,ISNULL(R.RejectedQty,0)              GRNRejectedQty
      ,ISNULL(R.ChallanQtyAgainstGE,0)      ChallanQtyAgainstGE
      ,ISNULL(R.BalanceBasisQty,0)          ReceiptQtyAsPerSetting
      ,ISNULL(R.CancelBasisQty,0)           CancelBasisQty
      ,ISNULL(R.AcceptedValue,0)            AcceptedValue
      ,ISNULL(R.ReceiptDocCount,0)          ReceiptDocCount
      ,R.FirstReceiptDate
      ,R.LastReceiptDate
      ,ISNULL(B.BilledQty,0)                BilledQty
      ,ISNULL(BA.BilledBasicAmount,0)       BilledBasicAmount
      ,ISNULL(BC.BillCount,0)               BillCount
      ,BC.LastBillDate
      ,C.CancelStatusNo
      ,CQ.CancelQty
      ,BQ.POBalanceQty
INTO #Summary
FROM #POItem PI
OUTER APPLY (
              Select SUM(G.ChallanQty) GateEntryQty, COUNT(DISTINCT G.GateEntryNo) GateEntryCount, MIN(G.GateEntryDate) FirstGateEntryDate
              From #GE G
              Where G.ItemNo = PI.ItemNo And G.MakeNo = PI.MakeNo And G.TechnicalGradeNo = PI.TechnicalGradeNo
            ) GE
OUTER APPLY (
              Select SUM(RC.ChallanQty)  ChallanQty
                    ,SUM(RC.ReceivedQty) ReceivedQty
                    ,SUM(RC.AcceptedQty) AcceptedQty
                    ,SUM(RC.RejectedQty) RejectedQty
                    ,SUM(CASE WHEN RC.GateEntryNo IS NOT NULL THEN RC.ChallanQty ELSE 0 END) ChallanQtyAgainstGE
                    -- same rule as MIS PO Progress Flow [PO Balance Qty.]
                    ,SUM(CASE WHEN P.POBalancedQty IN (1,2) THEN RC.ChallanQty - RC.RejectedQty
                              WHEN P.POBalancedQty = 3 THEN CASE RC.FlowType WHEN 'GRN' THEN RC.AcceptedQty WHEN 'GRN-BOQ' THEN RC.ReceivedQty ELSE 0 END
                              WHEN P.POBalancedQty = 4 THEN CASE RC.FlowType WHEN 'GRN' THEN RC.ReceivedQty ELSE RC.AcceptedQty END
                         END) BalanceBasisQty
                    -- same rule as MIS PO Progress Flow #TempCancelPO
                    ,SUM(CASE WHEN RC.FlowType = 'GRN-BOQ' THEN 0
                              WHEN P.POBalancedQty IN (1,2) THEN RC.ChallanQty
                              WHEN P.POBalancedQty = 3 THEN CASE RC.FlowType WHEN 'GRN' THEN RC.AcceptedQty ELSE 0 END
                              WHEN P.POBalancedQty = 4 THEN CASE RC.FlowType WHEN 'GRN' THEN RC.ReceivedQty ELSE RC.AcceptedQty END
                         END) CancelBasisQty
                    ,SUM(CASE WHEN RC.FlowType = 'GRN-BOQ' THEN RC.AcceptedQty * ISNULL(RC.Rate,0)
                              ELSE RC.AcceptedQty * ISNULL(P.RateAfterDiscount,0) END) AcceptedValue
                    ,COUNT(DISTINCT CONCAT(RC.FlowType, '-', RC.DocNo)) ReceiptDocCount
                    ,MIN(RC.DocDate) FirstReceiptDate
                    ,MAX(RC.DocDate) LastReceiptDate
              From #Rcpt RC
              -- PO line values as inner columns (SQL Server disallows outer refs mixed with inner columns inside SUM)
              Cross Join (Select PI.POBalancedQty, PI.RateAfterDiscount) P
              Where RC.ItemNo = PI.ItemNo And RC.MakeNo = PI.MakeNo
                And (RC.TechnicalGradeNo IS NULL Or RC.TechnicalGradeNo = PI.TechnicalGradeNo)
            ) R
OUTER APPLY (
              Select SUM(RC.AcceptedQty) BilledQty
              From #Rcpt RC
              Where RC.ItemNo = PI.ItemNo And RC.MakeNo = PI.MakeNo
                And (RC.TechnicalGradeNo IS NULL Or RC.TechnicalGradeNo = PI.TechnicalGradeNo)
                And EXISTS (Select 1 From #Bill BL Where BL.RcptRowId = RC.RowId)
            ) B
OUTER APPLY (
              Select SUM(X.BasicAmount) BilledBasicAmount
              From (
                     Select Distinct BL.PurchaseBillNo, RC.FlowType, RC.DocNo, RC.RcvItemNo, RC.RcvMakeNo, RC.RcvTechnicalGradeNo, BL.BasicAmount
                     From #Bill BL
                     Inner Join #Rcpt RC On RC.RowId = BL.RcptRowId
                     Where RC.ItemNo = PI.ItemNo And RC.MakeNo = PI.MakeNo
                       And (RC.TechnicalGradeNo IS NULL Or RC.TechnicalGradeNo = PI.TechnicalGradeNo)
                   ) X
            ) BA
OUTER APPLY (
              Select COUNT(DISTINCT BL.PurchaseBillNo) BillCount, MAX(BH.DocumentDate) LastBillDate
              From #Bill BL
              Inner Join #Rcpt RC On RC.RowId = BL.RcptRowId
              Inner Join #BillHead BH On BH.PurchaseBillNo = BL.PurchaseBillNo
              Where RC.ItemNo = PI.ItemNo And RC.MakeNo = PI.MakeNo
                And (RC.TechnicalGradeNo IS NULL Or RC.TechnicalGradeNo = PI.TechnicalGradeNo)
            ) BC
LEFT JOIN #Cancel C ON C.ItemNo = PI.ItemNo
                   AND C.MakeNo = PI.MakeNo
                   AND C.TechnicalGradeNo = PI.TechnicalGradeNo
CROSS APPLY (
              Select CASE WHEN C.CancelStatusNo IS NOT NULL
                          THEN CONVERT(decimal(18,3), C.AmendmentQty - ISNULL(R.CancelBasisQty,0)) END CancelQty
            ) CQ
CROSS APPLY (
              Select CASE WHEN PI.ItemTypeNo = 14 OR PI.POBalancedQty IS NULL THEN CONVERT(decimal(18,3), NULL)
                          ELSE CONVERT(decimal(18,3), PI.Quantity - (ISNULL(R.BalanceBasisQty,0) + ISNULL(CQ.CancelQty,0))) END POBalanceQty
            ) BQ;

--------------------------------------------------------------------------
-- RESULT SET 0 : Metadata
--------------------------------------------------------------------------
DECLARE @Meta TABLE
(
     SeqNo        int IDENTITY(1,1)
    ,Section      varchar(20)
    ,ResultSetNo  int NULL
    ,Name         varchar(100)
    ,Grain        varchar(200) NULL
    ,KeyColumns   varchar(200) NULL
    ,Description  varchar(1000)
);

INSERT INTO @Meta (Section, ResultSetNo, Name, Grain, KeyColumns, Description) VALUES
 ('SP_INFO',      NULL, 'Purchase.AIPOInsight', NULL, NULL, 'Complete life-cycle of one Purchase Order (PO): header, items, taxes, gate entry, goods receipt, purchase bill, quantity reconciliation. Every call returns result sets 0-9 in this order with fixed columns; a set is empty when no data exists.')
,('EXECUTION',    NULL, 'Status',          NULL, NULL, @Status)
,('EXECUTION',    NULL, 'StatusMessage',   NULL, NULL, @StatusMessage)
,('EXECUTION',    NULL, 'ResolvedPONo',    NULL, NULL, CONVERT(varchar(20), NULLIF(@TempPONo,-1)))
,('EXECUTION',    NULL, 'ExecutedOn',      NULL, NULL, CONVERT(varchar(30), GETDATE(), 120))
,('PARAMETER',    NULL, '@PONo',           NULL, NULL, 'Internal PO key (Purchase.POMain.PONo). Takes priority over @PONoYearly.')
,('PARAMETER',    NULL, '@PONoYearly',     NULL, NULL, 'PO document number as shown to users. Used only when @PONo is NULL.')
,('PARAMETER',    NULL, '@CompanyNo',      NULL, NULL, 'Optional. Required when the same @PONoYearly exists in more than one company.')

,('RESULT_SET',   0, 'Metadata',       'One row per metadata entry', 'SeqNo', 'This table. Read EXECUTION rows first: if Status is not OK all other sets are empty.')
,('RESULT_SET',   1, 'POHeader',       'One row per PO', 'PONo', 'PO header: company, vendor, document/purchase type, reference document, currency, validity, latest amendment, authorization, item status mix.')
,('RESULT_SET',   2, 'POItem',         'One row per PO line', 'POItemDetailNo; ItemNo+MakeNo+TechnicalGradeNo', 'Ordered items with qty, rate, discount, value, HSN, tolerance, schedule dates, indent reference, line status and the qty basis used for balance.')
,('RESULT_SET',   3, 'POItemTax',      'One row per item tax/charge line', 'POItemTaxNo; ItemNo+MakeNo', 'Item-level taxes, discounts and charges (Purchase.POItemTaxDetail, ChargeOn = On Item).')
,('RESULT_SET',   4, 'POTaxSummary',   'One row per PO tax/charge head', 'PoTaxNo', 'PO-level tax/charge totals (Purchase.POTaxDetail) for both On Order and On Item charges, with GST sequence (Before GST / GST / After GST).')
,('RESULT_SET',   5, 'GateEntry',      'One row per gate entry line', 'GateEntryNo+ItemNo+MakeNo+TechnicalGradeNo', 'Material arrival at gate against this PO (Standard and Discrete RM), with qty already converted to GRN/SIN and pending at gate.')
,('RESULT_SET',   6, 'Receipt',        'One row per GRN line / SIN line', 'FlowType+ReceiptNo+ReceiptLineNo', 'Goods receipt: GRN (incl. MRA without gate entry), SC-BOQ GRN, Discrete RM SIN. Challan / received / accepted / rejected qty, warehouse, billing flag.')
,('RESULT_SET',   7, 'PurchaseBill',   'One row per bill line x receipt document x item', 'PurchaseBillNo+ReceiptFlowType+ReceiptNo+ItemNo+MakeNo', 'Purchase bills booked against the receipts of this PO, billed qty, basic amount, bill net amount and outstanding payable.')
,('RESULT_SET',   8, 'ItemQtySummary', 'One row per PO line', 'POItemDetailNo; ItemNo+MakeNo+TechnicalGradeNo', 'Quantity reconciliation per item: PO qty > gate entry > GRN > billed, cancel qty, PO balance, values, dates, delay and InsightFlags.')
,('RESULT_SET',   9, 'POSummary',      'One row per PO', 'PONo', 'PO-level roll-up: counts, total quantities, values, outstanding, key dates, overall status and InsightFlags.')

,('BUSINESS_RULE',NULL, 'PO line key',            NULL, NULL, 'A PO line is identified by ItemNo + MakeNo + TechnicalGradeNo (0 means not specified). Use it to join sets 2, 3, 5, 6, 8. Set 3 has no TechnicalGradeNo.')
,('BUSINESS_RULE',NULL, 'Qty basis setting',      NULL, NULL, 'Purchase.POQtySetting.POBalancedQty per item type decides which receipt qty reduces the PO balance: 1 or 2 = Challan - Rejected; 3 = Accepted (GRN), Received (SC-BOQ), SIN not counted; 4 = Received (GRN), Accepted (SIN / SC-BOQ). Shown as QtyBasisForBalance. Same rule as the MIS PO Progress Flow report.')
,('BUSINESS_RULE',NULL, 'PO balance',             NULL, NULL, 'POBalanceQty = POQty - (ReceiptQtyAsPerSetting + CancelQty). Positive = still to receive, 0 = complete, negative = received more than ordered. NULL for SC-BOQ items (ItemTypeNo 14) or when no qty setting exists.')
,('BUSINESS_RULE',NULL, 'Cancel qty',             NULL, NULL, 'A line is cancelled / short-closed when Change PO Status sets it to status 4 or 7. CancelQty = qty on that amendment - qty already received before cancel. NULL when the line is not cancelled.')
,('BUSINESS_RULE',NULL, 'Gate entry scope',       NULL, NULL, 'Only gate entries whose source is Purchase Order (GateEntrySourceNo = 2). ModuleNo 2 = Standard purchase, ModuleNo 19 = Discrete RM.')
,('BUSINESS_RULE',NULL, 'Receipt scope',          NULL, NULL, 'GRN lines linked to any amendment of the PO. For transport-route POs only the final leg (whole-number RouteIdentity) is counted. GRN-BOQ rows are sub-items received against an SC-BOQ PO line (mapped back to that PO line). SIN = Discrete RM store inward.')
,('BUSINESS_RULE',NULL, 'Billed qty',             NULL, NULL, 'BilledQty = accepted qty of receipt lines that appear in a purchase bill. Partial billing of a single receipt line cannot be detected, so the whole line counts as billed.')
,('BUSINESS_RULE',NULL, 'Bill level amounts',     NULL, NULL, 'BillNetAmount and BillOutstandingAmount are per bill and repeat on every line of set 7. One bill can cover several POs, so these can exceed this PO''s value.')
,('BUSINESS_RULE',NULL, 'Amounts and currency',   NULL, NULL, 'Amounts are in PO currency unless the column name ends with BaseCurrency. POBasicValue / AcceptedValue use the rate after discount.')
,('BUSINESS_RULE',NULL, 'Mixed units',            NULL, NULL, 'Quantity totals in set 9 add up different items and units of measure. Compare items with value columns or percentages, not with summed quantities.')
,('BUSINESS_RULE',NULL, 'Dates',                  NULL, NULL, 'ScheduleDelayDays: positive = late, negative = early. Measured to LastReceiptDate when fully received, otherwise to today. NULL for cancelled lines or lines without schedule.')

,('COLUMN',       8, 'POQty',                   NULL, NULL, 'Ordered qty on the current PO.')
,('COLUMN',       8, 'GateEntryQty',            NULL, NULL, 'Challan qty recorded at gate.')
,('COLUMN',       8, 'PendingGRNAtGateQty',     NULL, NULL, 'Gate entry qty not yet converted into GRN/SIN (GateEntryQty - challan qty of receipts that reference a gate entry).')
,('COLUMN',       8, 'GRNChallanQty',           NULL, NULL, 'Qty as per supplier challan on GRN/SIN.')
,('COLUMN',       8, 'GRNReceivedQty',          NULL, NULL, 'Qty physically received.')
,('COLUMN',       8, 'GRNAcceptedQty',          NULL, NULL, 'Qty accepted after inspection.')
,('COLUMN',       8, 'GRNRejectedQty',          NULL, NULL, 'Qty rejected.')
,('COLUMN',       8, 'ReceiptQtyAsPerSetting',  NULL, NULL, 'Receipt qty that reduces the PO balance, chosen by QtyBasisForBalance.')
,('COLUMN',       8, 'BilledQty',               NULL, NULL, 'Accepted qty covered by purchase bills.')
,('COLUMN',       8, 'PendingBillingQty',       NULL, NULL, 'GRNAcceptedQty - BilledQty: accepted but not yet billed.')
,('COLUMN',       8, 'CancelQty',               NULL, NULL, 'Qty cancelled / short-closed (see Cancel qty rule).')
,('COLUMN',       8, 'POBalanceQty',            NULL, NULL, 'Qty still to be received (see PO balance rule).')
,('COLUMN',       8, 'ReceiptFulfilmentPct',    NULL, NULL, 'ReceiptQtyAsPerSetting / POQty * 100.')
,('COLUMN',       8, 'RejectionPct',            NULL, NULL, 'GRNRejectedQty / GRNChallanQty * 100.')
,('COLUMN',       8, 'InsightFlags',            NULL, NULL, 'Comma separated: NO_PO_QTY_SETTING, SC_BOQ_ITEM, CANCELLED_OR_SHORT_CLOSED, NO_MOVEMENT, FULLY_RECEIVED, EXCESS_RECEIPT, PARTIALLY_RECEIVED, OVERDUE, PENDING_GRN_AT_GATE, REJECTION, PENDING_BILLING, NEGATIVE_CANCEL_QTY.')
,('COLUMN',       9, 'OverallStatus',           NULL, NULL, 'NO_ITEMS, CANCELLED (all lines cancelled), COMPLETED (no open balance), PARTIALLY_RECEIVED, NOT_STARTED (nothing received).')
,('COLUMN',       9, 'ValueFulfilmentPct',      NULL, NULL, 'AcceptedValue / POBasicValue * 100 (unit independent).')
,('COLUMN',       9, 'InsightFlags',            NULL, NULL, 'Comma separated: NOT_AUTHORIZED, VALIDITY_EXPIRED_WITH_BALANCE, HAS_OVERDUE_ITEMS, HAS_EXCESS_RECEIPT, HAS_REJECTION, PENDING_GRN_AT_GATE, PENDING_BILLING, PAYMENT_OUTSTANDING, AMENDED.')

,('ANALYSIS_HINT',NULL, 'Delivery performance',   NULL, NULL, 'Use set 8 ScheduleDelayDays, OVERDUE flag and set 9 LeadTimeDays to judge vendor delivery.')
,('ANALYSIS_HINT',NULL, 'Quality',                NULL, NULL, 'Use RejectionPct (set 8) and rejected qty per receipt (set 6).')
,('ANALYSIS_HINT',NULL, 'Stuck material',         NULL, NULL, 'PendingGRNAtGateQty > 0 means material is at the gate but not receipted; set 5 shows which gate entries.')
,('ANALYSIS_HINT',NULL, 'Finance',                NULL, NULL, 'PendingBillingQty (accepted but not billed) and OutstandingPayable (billed but not paid).');

SELECT SeqNo, Section, ResultSetNo, Name, Grain, KeyColumns, Description
FROM @Meta
ORDER BY SeqNo;

--------------------------------------------------------------------------
-- RESULT SET 1 : POHeader
--------------------------------------------------------------------------
SELECT PM.PONo
      ,PM.DocumentNoYearly                                         AS PONoYearly
      ,PM.DocumentDate                                             AS PODate
      ,PM.CompanyNo
      ,CM.CompanyName
      ,DV.DivisionName
      ,DM.DeptName                                                 AS Department
      ,PODT.DocumentType                                           AS PODocumentType
      ,POPT.IndentType                                             AS PurchaseType
      ,POPC.PurchaseCategory
      ,PORT.RefDocumentType
      ,COALESCE(RQM.DocumentNoYearly, AGM.DocumentNoYearly, LOI.DocumentNoYearly) AS RefDocumentNoYearly
      ,COALESCE(RQM.DocumentDate, AGM.DocumentDate, LOI.DocumentDate)             AS RefDocumentDate
      ,PM.VendorLocationNo
      ,VLD.VendorName
      ,VLD.FullAddress                                             AS VendorLocation
      ,VLCD.ContactPersonName                                      AS VendorContactPerson
      ,AN.AgentName
      ,CUM.Name                                                    AS Currency
      ,CONVERT(decimal(12,6), PM.MultiplicativeRate * PM.DivisibilityRate) AS ExchangeRate
      ,PM.ReferenceNo                                              AS POReferenceNo
      ,PM.ReferenceDate                                            AS POReferenceDate
      ,PM.WayBillNo
      ,PM.WayBillDate
      ,PM.ValidityDate
      ,CASE WHEN PM.ValidityDate IS NULL THEN NULL
            WHEN PM.ValidityDate >= @Today THEN 'Active' ELSE 'Expired' END AS ValidityStatus
      ,LA.AmendmentNo                                              AS LatestAmendmentNo
      ,LA.POAmendmentDate                                          AS LatestAmendmentDate
      ,LA.AmendmentReason                                          AS LatestAmendmentReason
      ,LA.NetAmount                                                AS PONetAmount
      ,CONVERT(decimal(18,2), LA.NetAmount * PM.MultiplicativeRate * PM.DivisibilityRate) AS PONetAmountBaseCurrency
      ,CASE WHEN ISNULL(PM.AuthorizedBy,0) > 0 THEN 'Yes' ELSE 'No' END AS IsAuthorized
      ,PM.AuthorizedDate
      ,SLA.PrintingName                                            AS AuthorizedBy
      ,SLC.PrintingName                                            AS CreatedBy
      ,SLR.PrintingName                                            AS ReleasedBy
      ,CONVERT(bit, ISNULL(LA.IsTransportationRouteApplicable,0))  AS IsTransportationRouteApplicable
      ,(SELECT COUNT(1) FROM #POItem)                              AS ItemCount
      ,STUFF((
              Select ', ' + GS.StatusName + ' (' + CONVERT(varchar(10), COUNT(1)) + ')'
              From #POItem P
              Inner Join GlobalData.Status GS On GS.StatusNo = P.StatusNo
              Group By GS.StatusName
              For Xml Path('')
             ),1,2,'')                                             AS ItemStatusMix
      ,DATEDIFF(DAY, PM.DocumentDate, @Today)                      AS POAgeDays
FROM Purchase.POMain PM
INNER JOIN masterdata.mCompanyMaster CM ON CM.CompanyNo = PM.CompanyNo
LEFT JOIN payroll.tblDivisionMaster DV ON DV.DivisionNo = PM.DivisionNo
LEFT JOIN payroll.tblDeptMaster DM ON DM.DeptNo = PM.DeptNo
LEFT JOIN GlobalData.PODocumentType PODT ON PODT.PODocumentTypeNo = PM.PODocumentTypeNo
LEFT JOIN GlobalData.IndentType POPT ON POPT.IndentTypeNo = PM.IndentTypeNo
LEFT JOIN GlobalData.PORefDocumentType PORT ON PORT.PORefDocumentTypeNo = PM.PORefDocumentTypeNo
LEFT JOIN GlobalData.POPurchaseCategory POPC ON POPC.POPurchaseCategoryNo = PM.POPurchaseCategoryNo
LEFT JOIN masterdata.mVendorLocationDetail VLD ON VLD.VendorLocationNo = PM.VendorLocationNo
LEFT JOIN masterdata.mVendorLocationContactDetail VLCD ON VLCD.VendorContactNo = PM.VendorContactNo
LEFT JOIN masterdata.mCurrencyConversion CC ON CC.CurrencyConversionNo = PM.CurrencyConversionNo
LEFT JOIN masterdata.mCurrencyMaster CUM ON CUM.CurrencyNo = CC.ExchangeCurrencyNo
LEFT JOIN Purchase.RevisedQuotationMain RQM ON RQM.RevisedQuotationNo = PM.RefDocumentNo
                                           AND PM.PORefDocumentTypeNo = 1
LEFT JOIN Purchase.AgreementMain AGM ON AGM.AgreementNo = PM.RefDocumentNo
                                    AND (PM.PORefDocumentTypeNo = 2 OR (PM.PORefDocumentTypeNo = 8 AND PM.IsCSAgainstAgreement = 1))
LEFT JOIN Purchase.POAmendmentMain LOI ON LOI.POAmendmentNo = PM.RefDocumentNo
                                      AND PM.PORefDocumentTypeNo = 4
LEFT JOIN [Security].[Login] SLA ON SLA.LoginNo = PM.AuthorizedBy
OUTER APPLY (
              Select Top 1 PAM.AmendmentNo, PAM.POAmendmentDate, PAM.AmendmentReason, PAM.NetAmount, PAM.ReleasedBy, PAM.IsTransportationRouteApplicable
              From Purchase.POAmendmentMain PAM
              Where PAM.PONo = PM.PONo
              Order By PAM.AmendmentNo Desc
            ) LA
OUTER APPLY (
              Select Top 1 PAM.CreatedBy
              From Purchase.POAmendmentMain PAM
              Where PAM.PONo = PM.PONo
              Order By PAM.AmendmentNo
            ) FA
LEFT JOIN [Security].[Login] SLC ON SLC.LoginNo = FA.CreatedBy
LEFT JOIN [Security].[Login] SLR ON SLR.LoginNo = LA.ReleasedBy
OUTER APPLY (
              Select Top 1 VC.Name AgentName
              From Purchase.POExpenseHead EH
              Inner Join masterdata.mExpenseHead EHM On EHM.ExpenseHeadNo = EH.ExpenseHeadNo
              Inner Join masterdata.mVendorCard VC On VC.VendorNo = EH.PartyNo
              Where EH.PONo = PM.PONo
                And EHM.ExpenseHeadName = 'Commission'
            ) AN
WHERE PM.PONo = @TempPONo;

--------------------------------------------------------------------------
-- RESULT SET 2 : POItem
--------------------------------------------------------------------------
SELECT PI.POItemDetailNo
      ,PI.ItemNo
      ,PI.MakeNo
      ,PI.TechnicalGradeNo
      ,V.FullCode                       AS ItemCode
      ,V.ItemName
      ,V.ItemDescription
      ,ITMT.Type                        AS ItemType
      ,V.Make                           AS MakeName
      ,V.TechnicalGradeName
      ,V.TechSpecification
      ,V.Unit                           AS UOM
      ,V.HSNSACCode
      ,PI.Quantity                      AS POQty
      ,PI.Rate
      ,PI.DiscountAmount
      ,PI.RateAfterDiscount
      ,PI.BasicValue                    AS BasicValueAfterDiscount
      ,V.GSTTaxable
      ,PI.NetAmount
      ,V.ToleranceBasisNo
      ,V.TolerancePlus
      ,V.ToleranceMinus
      ,PI.MinScheduleDate
      ,PI.MaxScheduleDate
      ,V.IndentDocumentNoYearly         AS IndentReference
      ,V.CostCenterName
      ,V.ItemRemark
      ,GS.StatusName                    AS LineStatus
      ,PI.POBalancedQty
      ,CASE PI.POBalancedQty WHEN 1 THEN 'Challan - Rejected'
                             WHEN 2 THEN 'Challan - Rejected'
                             WHEN 3 THEN 'Accepted'
                             WHEN 4 THEN 'Received'
                             ELSE 'Not configured' END AS QtyBasisForBalance
FROM #POItem PI
INNER JOIN Purchase.vwdpPoitem V ON V.POItemDetailNo = PI.POItemDetailNo
LEFT JOIN GlobalData.ItemType ITMT ON ITMT.ItemTypeNo = PI.ItemTypeNo
LEFT JOIN GlobalData.Status GS ON GS.StatusNo = PI.StatusNo
WHERE V.PONo = @TempPONo
ORDER BY PI.POItemDetailNo;

--------------------------------------------------------------------------
-- RESULT SET 3 : POItemTax
--------------------------------------------------------------------------
SELECT T.POItemTaxNo
      ,T.ItemNo
      ,T.MakeNo
      ,T.ItemDescription
      ,T.MakeName
      ,T.MiscChargeName                 AS ChargeName
      ,T.TaxGroupNo
      ,T.GroupCode                      AS TaxGroupCode
      ,T.ChargeType                     -- (Inc.) inclusive / (Exc.) exclusive
      ,T.Nature                         -- (%) / (Amt) / (Unit)
      ,T.ChargeValue
      ,T.TotalAmount
      ,T.CalculationNature
      ,CASE T.CalculationNature WHEN 1 THEN 'Add' WHEN 2 THEN 'Deduct' ELSE 'Other' END AS CalculationEffect
      ,T.SerialOrderNo
FROM Purchase.vwdpPOItemTaxDetail T
WHERE T.PONo = @TempPONo
ORDER BY T.ItemNo, T.MakeNo, T.SerialOrderNo;

--------------------------------------------------------------------------
-- RESULT SET 4 : POTaxSummary
--------------------------------------------------------------------------
SELECT T.PoTaxNo
      ,T.ChargeName
      ,T.TaxGroupNo
      ,T.TaxGroupName
      ,T.GroupCode                      AS TaxGroupCode
      ,CASE T.ChargeOn WHEN 1 THEN 'On Order' WHEN 2 THEN 'On Item' ELSE 'Other' END AS ChargeOn
      ,T.ChargeType
      ,T.Nature
      ,T.ChargeValue
      ,T.ActualTotalValue               AS TotalAmount
      ,T.TotalValue                     AS TotalAmountExclusiveOnly
      ,T.CalculationNature
      ,CASE T.CalculationNature WHEN 1 THEN 'Add' WHEN 2 THEN 'Deduct' ELSE 'Other' END AS CalculationEffect
      ,CASE T.GSTSequenceNo WHEN -1 THEN 'Before GST' WHEN 0 THEN 'GST' ELSE 'After GST' END AS GSTSequence
      ,T.SerialOrderNo
FROM Purchase.vwdpPOTaxDetail T
WHERE T.PONo = @TempPONo
ORDER BY T.SerialOrderNo;

--------------------------------------------------------------------------
-- RESULT SET 5 : GateEntry
--------------------------------------------------------------------------
SELECT G.FlowType
      ,G.GateEntryNo
      ,GEM.DocumentNoYearly             AS GateEntryNoYearly
      ,GEM.DocumentDate                 AS GateEntryDate
      ,GESD.SourceDocument
      ,VLD.VendorName
      ,VC.Name                          AS TransporterName
      ,GEM.DriverName
      ,GEM.VehicleNo
      ,GEM.LRNo
      ,GEM.LRDate
      ,GEM.ChallanNo
      ,GEM.ChallanDate
      ,G.POAmendmentNo
      ,G.ItemNo
      ,G.MakeNo
      ,G.TechnicalGradeNo
      ,IM.ItemDescription
      ,MM.MakeName
      ,UM.Alias                         AS UOM
      ,G.ChallanQty                     AS GateEntryQty
      ,ISNULL(RG.ReceiptChallanQty,0)   AS ReceiptedQty
      ,G.ChallanQty - ISNULL(RG.ReceiptChallanQty,0) AS PendingGRNQty
      ,DATEDIFF(DAY, GEM.DocumentDate, ISNULL(RG.FirstReceiptDate, @Today)) AS DaysGateToReceipt
      ,CASE WHEN ISNULL(GEM.AuthorizedBy,0) > 0 THEN 'Yes' ELSE 'No' END AS IsAuthorized
      ,GEM.AuthorizedDate
FROM #GE G
INNER JOIN GateEntry.InvGateEntryMain GEM ON GEM.GateEntryNo = G.GateEntryNo
LEFT JOIN GlobalData.GateEntrySourceDocument GESD ON GESD.GateEntrySourceNo = GEM.GateEntrySourceNo
LEFT JOIN masterdata.mVendorLocationDetail VLD ON VLD.VendorLocationNo = GEM.VendorLocationNo
LEFT JOIN masterdata.mVendorCard VC ON VC.VendorNo = GEM.TransporterNo AND VC.VendorTypeNo = 1
LEFT JOIN masterdata.mItemMaster IM ON IM.ItemNo = G.ItemNo
LEFT JOIN masterdata.mMakeMaster MM ON MM.MakeNo = NULLIF(G.RcvMakeNo,0)
LEFT JOIN #POItem PI ON PI.ItemNo = G.ItemNo AND PI.MakeNo = G.MakeNo AND PI.TechnicalGradeNo = G.TechnicalGradeNo
LEFT JOIN masterdata.mUnitMaster UM ON UM.UnitNo = PI.UnitNo
OUTER APPLY (
              Select SUM(RC.ChallanQty) ReceiptChallanQty, MIN(RC.DocDate) FirstReceiptDate
              From #Rcpt RC
              Where RC.GateEntryNo = G.GateEntryNo
                And RC.ItemNo = G.ItemNo And RC.MakeNo = G.MakeNo
                And (RC.TechnicalGradeNo IS NULL Or RC.TechnicalGradeNo = G.TechnicalGradeNo)
            ) RG
ORDER BY GEM.DocumentDate, G.GateEntryNo, G.ItemNo;

--------------------------------------------------------------------------
-- RESULT SET 6 : Receipt
--------------------------------------------------------------------------
SELECT R.FlowType
      ,R.DocNo                          AS ReceiptNo
      ,R.DocLineNo                      AS ReceiptLineNo
      ,R.DocNoYearly                    AS ReceiptNoYearly
      ,R.DocDate                        AS ReceiptDate
      ,CASE WHEN R.FlowType = 'SIN' THEN 'Discrete RM SIN' ELSE SD.SourceDocument END AS SourceDocument
      ,R.VendorBillNo
      ,R.VendorBillDate
      ,R.GateEntryNo
      ,GEM.DocumentNoYearly             AS GateEntryNoYearly
      ,R.POAmendmentNo
      ,R.ItemNo
      ,R.MakeNo
      ,R.TechnicalGradeNo
      ,R.RcvItemNo                      AS ReceivedItemNo
      ,IM.FullCode                      AS ReceivedItemCode
      ,IM.ItemDescription               AS ReceivedItemDescription
      ,MM.MakeName                      AS ReceivedMakeName
      ,TG.TechnicalGradeName            AS ReceivedTechnicalGrade
      ,R.ChallanQty
      ,R.ReceivedQty
      ,R.AcceptedQty
      ,R.RejectedQty
      ,R.Rate                           AS GRNRate
      ,MWH.WareHouseName
      ,DATEDIFF(DAY, PM.DocumentDate, R.DocDate) AS DaysFromPO
      ,CASE WHEN R.IsAuthorized = 1 THEN 'Yes' ELSE 'No' END AS IsAuthorized
      ,R.AuthorizedDate
      ,CASE WHEN EXISTS (SELECT 1 FROM #Bill BL WHERE BL.RcptRowId = R.RowId) THEN 'Yes' ELSE 'No' END AS IsBilled
FROM #Rcpt R
INNER JOIN Purchase.POMain PM ON PM.PONo = @TempPONo
LEFT JOIN GlobalData.GRNSourceDcoument SD ON SD.GRNSourceNo = R.SourceNo
LEFT JOIN GateEntry.InvGateEntryMain GEM ON GEM.GateEntryNo = R.GateEntryNo
LEFT JOIN masterdata.mItemMaster IM ON IM.ItemNo = R.RcvItemNo
LEFT JOIN masterdata.mMakeMaster MM ON MM.MakeNo = NULLIF(R.RcvMakeNo,0)
LEFT JOIN GlobalData.TechnicalGrade TG ON TG.TechnicalGradeNo = NULLIF(R.RcvTechnicalGradeNo,0)
LEFT JOIN masterdata.mWarehouse MWH ON MWH.WareHouseNo = R.WareHouseNo
ORDER BY R.DocDate, R.FlowType, R.DocNo, R.DocLineNo;

--------------------------------------------------------------------------
-- RESULT SET 7 : PurchaseBill
--------------------------------------------------------------------------
SELECT BH.PurchaseBillNo
      ,BH.DocumentNoYearly              AS PurchaseBillNoYearly
      ,BH.DocumentDate                  AS PurchaseBillDate
      ,BH.VendorBillNo
      ,BH.VendorBillDate
      ,R.FlowType                       AS ReceiptFlowType
      ,R.DocNo                          AS ReceiptNo
      ,R.DocNoYearly                    AS ReceiptNoYearly
      ,R.DocDate                        AS ReceiptDate
      ,R.ItemNo
      ,R.MakeNo
      ,R.TechnicalGradeNo
      ,IM.FullCode                      AS ItemCode
      ,IM.ItemDescription
      ,MM.MakeName
      ,SUM(R.AcceptedQty)               AS BilledQty
      ,B.BasicAmount                    AS BillLineBasicAmount
      ,BH.NetAmount                     AS BillNetAmount
      ,BH.OutstandingAmount             AS BillOutstandingAmount
      ,PMD.PaymentMode
      ,DATEDIFF(DAY, MIN(R.DocDate), BH.DocumentDate) AS DaysReceiptToBill
      ,BH.AuthorizedDate
FROM #Bill B
INNER JOIN #Rcpt R ON R.RowId = B.RcptRowId
INNER JOIN #BillHead BH ON BH.PurchaseBillNo = B.PurchaseBillNo
LEFT JOIN masterdata.mItemMaster IM ON IM.ItemNo = R.RcvItemNo
LEFT JOIN masterdata.mMakeMaster MM ON MM.MakeNo = NULLIF(R.RcvMakeNo,0)
LEFT JOIN GlobalData.PaymentMode PMD ON PMD.PaymentModeNo = BH.PaymentModeNo
GROUP BY BH.PurchaseBillNo, BH.DocumentNoYearly, BH.DocumentDate, BH.VendorBillNo, BH.VendorBillDate
        ,R.FlowType, R.DocNo, R.DocNoYearly, R.DocDate, R.ItemNo, R.MakeNo, R.TechnicalGradeNo
        ,IM.FullCode, IM.ItemDescription, MM.MakeName, B.BasicAmount
        ,BH.NetAmount, BH.OutstandingAmount, PMD.PaymentMode, BH.AuthorizedDate
ORDER BY BH.DocumentDate, BH.PurchaseBillNo, R.DocNo;

--------------------------------------------------------------------------
-- RESULT SET 8 : ItemQtySummary
--------------------------------------------------------------------------
SELECT S.POItemDetailNo
      ,S.ItemNo
      ,S.MakeNo
      ,S.TechnicalGradeNo
      ,IM.FullCode                      AS ItemCode
      ,IM.ItemDescription
      ,MM.MakeName
      ,TG.TechnicalGradeName
      ,UM.Alias                         AS UOM
      ,GS.StatusName                    AS LineStatus
      ,CASE S.POBalancedQty WHEN 1 THEN 'Challan - Rejected'
                            WHEN 2 THEN 'Challan - Rejected'
                            WHEN 3 THEN 'Accepted'
                            WHEN 4 THEN 'Received'
                            ELSE 'Not configured' END AS QtyBasisForBalance
      ,S.Quantity                       AS POQty
      ,S.GateEntryQty
      ,S.GateEntryQty - S.ChallanQtyAgainstGE AS PendingGRNAtGateQty
      ,S.GRNChallanQty
      ,S.GRNReceivedQty
      ,S.GRNAcceptedQty
      ,S.GRNRejectedQty
      ,S.ReceiptQtyAsPerSetting
      ,S.BilledQty
      ,S.GRNAcceptedQty - S.BilledQty   AS PendingBillingQty
      ,S.CancelQty
      ,S.POBalanceQty
      ,CONVERT(decimal(9,2), S.ReceiptQtyAsPerSetting * 100.0 / NULLIF(S.Quantity,0))  AS ReceiptFulfilmentPct
      ,CONVERT(decimal(9,2), S.GRNRejectedQty * 100.0 / NULLIF(S.GRNChallanQty,0))     AS RejectionPct
      ,S.RateAfterDiscount
      ,S.BasicValue                     AS POBasicValue
      ,CONVERT(decimal(18,2), S.AcceptedValue) AS AcceptedValue
      ,S.BilledBasicAmount
      ,S.GateEntryCount
      ,S.ReceiptDocCount
      ,S.BillCount
      ,S.MinScheduleDate
      ,S.MaxScheduleDate
      ,S.FirstGateEntryDate
      ,S.FirstReceiptDate
      ,S.LastReceiptDate
      ,S.LastBillDate
      ,CASE WHEN S.CancelStatusNo IS NOT NULL OR S.MaxScheduleDate IS NULL OR S.POBalanceQty IS NULL THEN NULL
            WHEN S.POBalanceQty <= 0 THEN DATEDIFF(DAY, S.MaxScheduleDate, S.LastReceiptDate)
            ELSE DATEDIFF(DAY, S.MaxScheduleDate, @Today) END AS ScheduleDelayDays
      ,STUFF(CONCAT(
              CASE WHEN S.POBalancedQty IS NULL THEN ',NO_PO_QTY_SETTING' END
             ,CASE WHEN S.ItemTypeNo = 14 THEN ',SC_BOQ_ITEM' END
             ,CASE WHEN S.CancelStatusNo IS NOT NULL THEN ',CANCELLED_OR_SHORT_CLOSED' END
             ,CASE WHEN S.CancelStatusNo IS NULL AND S.GateEntryQty = 0 AND S.ReceiptDocCount = 0 THEN ',NO_MOVEMENT' END
             ,CASE WHEN S.POBalanceQty = 0 THEN ',FULLY_RECEIVED' END
             ,CASE WHEN S.POBalanceQty < 0 THEN ',EXCESS_RECEIPT' END
             ,CASE WHEN S.POBalanceQty > 0 AND S.ReceiptDocCount > 0 THEN ',PARTIALLY_RECEIVED' END
             ,CASE WHEN S.POBalanceQty > 0 AND S.CancelStatusNo IS NULL AND S.MaxScheduleDate < @Today THEN ',OVERDUE' END
             ,CASE WHEN S.GateEntryQty - S.ChallanQtyAgainstGE > 0 THEN ',PENDING_GRN_AT_GATE' END
             ,CASE WHEN S.GRNRejectedQty > 0 THEN ',REJECTION' END
             ,CASE WHEN S.GRNAcceptedQty - S.BilledQty > 0 THEN ',PENDING_BILLING' END
             ,CASE WHEN S.CancelQty < 0 THEN ',NEGATIVE_CANCEL_QTY' END
            ),1,1,'') AS InsightFlags
FROM #Summary S
LEFT JOIN masterdata.mItemMaster IM ON IM.ItemNo = S.ItemNo
LEFT JOIN masterdata.mMakeMaster MM ON MM.MakeNo = NULLIF(S.MakeNo,0)
LEFT JOIN GlobalData.TechnicalGrade TG ON TG.TechnicalGradeNo = NULLIF(S.TechnicalGradeNo,0)
LEFT JOIN masterdata.mUnitMaster UM ON UM.UnitNo = S.UnitNo
LEFT JOIN GlobalData.Status GS ON GS.StatusNo = S.StatusNo
ORDER BY S.POItemDetailNo;

--------------------------------------------------------------------------
-- RESULT SET 9 : POSummary
--------------------------------------------------------------------------
;WITH T AS
(
    SELECT COUNT(1)                                                                AS TotalItems
          ,SUM(CASE WHEN CancelStatusNo IS NOT NULL THEN 1 ELSE 0 END)             AS CancelledItems
          ,SUM(CASE WHEN CancelStatusNo IS NULL AND POBalanceQty <= 0 THEN 1 ELSE 0 END) AS CompletedItems
          ,SUM(CASE WHEN CancelStatusNo IS NULL AND POBalanceQty > 0 THEN 1 ELSE 0 END)  AS OpenItems
          ,SUM(CASE WHEN CancelStatusNo IS NULL AND POBalanceQty > 0 AND MaxScheduleDate < @Today THEN 1 ELSE 0 END) AS OverdueItems
          ,SUM(CASE WHEN POBalanceQty < 0 THEN 1 ELSE 0 END)                       AS ExcessReceiptItems
          ,SUM(CASE WHEN ReceiptDocCount > 0 THEN 1 ELSE 0 END)                    AS ItemsWithReceipt
          ,SUM(Quantity)                                                           AS TotalPOQty
          ,SUM(GateEntryQty)                                                       AS TotalGateEntryQty
          ,SUM(GateEntryQty - ChallanQtyAgainstGE)                                 AS TotalPendingGRNAtGateQty
          ,SUM(GRNChallanQty)                                                      AS TotalGRNChallanQty
          ,SUM(GRNAcceptedQty)                                                     AS TotalGRNAcceptedQty
          ,SUM(GRNRejectedQty)                                                     AS TotalGRNRejectedQty
          ,SUM(ReceiptQtyAsPerSetting)                                             AS TotalReceiptQtyAsPerSetting
          ,SUM(BilledQty)                                                          AS TotalBilledQty
          ,SUM(GRNAcceptedQty - BilledQty)                                         AS TotalPendingBillingQty
          ,SUM(ISNULL(CancelQty,0))                                                AS TotalCancelQty
          ,SUM(CASE WHEN POBalanceQty > 0 THEN POBalanceQty ELSE 0 END)            AS TotalPOBalanceQty
          ,SUM(BasicValue)                                                         AS POBasicValue
          ,SUM(AcceptedValue)                                                      AS AcceptedValue
          ,SUM(BilledBasicAmount)                                                  AS BilledBasicAmount
          ,MAX(MaxScheduleDate)                                                    AS LastScheduleDate
          ,MIN(FirstReceiptDate)                                                   AS FirstReceiptDate
          ,MAX(LastReceiptDate)                                                    AS LastReceiptDate
          ,MAX(LastBillDate)                                                       AS LastBillDate
    FROM #Summary
)
SELECT PM.PONo
      ,PM.DocumentNoYearly                                         AS PONoYearly
      ,PM.DocumentDate                                             AS PODate
      ,VLD.VendorName
      ,LA.AmendmentNo                                              AS LatestAmendmentNo
      ,CASE WHEN ISNULL(PM.AuthorizedBy,0) > 0 THEN 'Yes' ELSE 'No' END AS IsAuthorized
      ,PM.ValidityDate
      ,T.TotalItems
      ,T.OpenItems
      ,T.CompletedItems
      ,T.CancelledItems
      ,T.OverdueItems
      ,T.ExcessReceiptItems
      ,(SELECT COUNT(DISTINCT GateEntryNo) FROM #GE)                                   AS GateEntryCount
      ,(SELECT COUNT(DISTINCT DocNo) FROM #Rcpt WHERE FlowType <> 'SIN')               AS GRNCount
      ,(SELECT COUNT(DISTINCT DocNo) FROM #Rcpt WHERE FlowType = 'SIN')                AS SINCount
      ,(SELECT COUNT(1) FROM #BillHead)                                                AS PurchaseBillCount
      ,T.TotalPOQty
      ,T.TotalGateEntryQty
      ,T.TotalPendingGRNAtGateQty
      ,T.TotalGRNChallanQty
      ,T.TotalGRNAcceptedQty
      ,T.TotalGRNRejectedQty
      ,T.TotalReceiptQtyAsPerSetting
      ,T.TotalBilledQty
      ,T.TotalPendingBillingQty
      ,T.TotalCancelQty
      ,T.TotalPOBalanceQty
      ,T.POBasicValue
      ,LA.NetAmount                                                                    AS PONetAmount
      ,CONVERT(decimal(18,2), T.AcceptedValue)                                         AS AcceptedValue
      ,T.BilledBasicAmount
      ,(SELECT SUM(NetAmount) FROM #BillHead)                                          AS BilledNetAmount
      ,(SELECT SUM(OutstandingAmount) FROM #BillHead)                                  AS OutstandingPayable
      ,CONVERT(decimal(9,2), T.AcceptedValue * 100.0 / NULLIF(T.POBasicValue,0))       AS ValueFulfilmentPct
      ,(SELECT MIN(GateEntryDate) FROM #GE)                                            AS FirstGateEntryDate
      ,T.FirstReceiptDate
      ,T.LastReceiptDate
      ,T.LastScheduleDate
      ,T.LastBillDate
      ,DATEDIFF(DAY, PM.DocumentDate, T.FirstReceiptDate)                              AS LeadTimeDays
      ,DATEDIFF(DAY, PM.DocumentDate, @Today)                                          AS POAgeDays
      ,CASE WHEN T.TotalItems = 0 THEN 'NO_ITEMS'
            WHEN T.CancelledItems = T.TotalItems THEN 'CANCELLED'
            WHEN T.OpenItems = 0 THEN 'COMPLETED'
            WHEN T.ItemsWithReceipt > 0 THEN 'PARTIALLY_RECEIVED'
            ELSE 'NOT_STARTED' END                                                     AS OverallStatus
      ,STUFF(CONCAT(
              CASE WHEN ISNULL(PM.AuthorizedBy,0) = 0 THEN ',NOT_AUTHORIZED' END
             ,CASE WHEN PM.ValidityDate < @Today AND T.OpenItems > 0 THEN ',VALIDITY_EXPIRED_WITH_BALANCE' END
             ,CASE WHEN T.OverdueItems > 0 THEN ',HAS_OVERDUE_ITEMS' END
             ,CASE WHEN T.ExcessReceiptItems > 0 THEN ',HAS_EXCESS_RECEIPT' END
             ,CASE WHEN T.TotalGRNRejectedQty > 0 THEN ',HAS_REJECTION' END
             ,CASE WHEN T.TotalPendingGRNAtGateQty > 0 THEN ',PENDING_GRN_AT_GATE' END
             ,CASE WHEN T.TotalPendingBillingQty > 0 THEN ',PENDING_BILLING' END
             ,CASE WHEN (SELECT SUM(OutstandingAmount) FROM #BillHead) > 0 THEN ',PAYMENT_OUTSTANDING' END
             ,CASE WHEN LA.AmendmentNo > 0 THEN ',AMENDED' END
            ),1,1,'')                                                                  AS InsightFlags
FROM Purchase.POMain PM
CROSS JOIN T
LEFT JOIN masterdata.mVendorLocationDetail VLD ON VLD.VendorLocationNo = PM.VendorLocationNo
OUTER APPLY (
              Select Top 1 PAM.AmendmentNo, PAM.NetAmount
              From Purchase.POAmendmentMain PAM
              Where PAM.PONo = PM.PONo
              Order By PAM.AmendmentNo Desc
            ) LA
WHERE PM.PONo = @TempPONo;

END TRY
BEGIN CATCH
    THROW;
END CATCH
END

GO


