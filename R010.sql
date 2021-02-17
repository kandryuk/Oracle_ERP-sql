WITH wrap AS (
--wrap is for etext output
SELECT
  ROWNUM "連番", main.*
--rownum should be apart from main select to avoid grouping by
FROM (
SELECT
    SEGMENT1 "会社番号"
  , d1 "会社名"
  , (PERIOD_YEAR - 1) "年度"
  , PERIOD_NAME "会計期間"
  , SEGMENT3 "勘定科目"
  , d3 "勘定科目名"
  , SEGMENT4 "取引先"
  , d4 "取引先名"
  , bb "期首残高"
  , DR "借方金額"
  , CR "貸方金額"
  , SUM(
      CASE WHEN d3flex IN ('A', 'E') THEN (bb + DR - CR)
      ELSE (bb + DR - CR) * (-1)
      END
    ) "当月残高"
  , :xdo_user_name "ユーザー名"
  , TO_CHAR(SYSDATE, 'YYYY/MM/DD') "出力日付"
  , TO_CHAR(SYSDATE, 'HH24:MM:SS') "出力時刻"

FROM
-- 仕訳明細(AFF別に集計)
  ( SELECT
      A.PERIOD_NAME
      , B.PERIOD_YEAR
      , A.CODE_COMBINATION_ID
      , C.SEGMENT1
      , C.SEGMENT3
      , C.SEGMENT4
      , D1.DESCRIPTION AS d1
      , D3.DESCRIPTION AS d3
      , D4.DESCRIPTION AS d4
      , D3.FLEX_VALUE_ATTRIBUTE3 as d3flex
      , SUM(NVL(A.ENTERED_DR, 0)) AS DR
      , SUM(NVL(A.ENTERED_CR, 0)) AS CR
      , SUM(
          CASE WHEN D3.FLEX_VALUE_ATTRIBUTE3 IN ('A', 'E') THEN (B.BEGIN_BALANCE_DR - B.BEGIN_BALANCE_CR)
          ELSE (B.BEGIN_BALANCE_DR - B.BEGIN_BALANCE_CR) * (-1)
          END
        ) AS bb

    FROM
        GL_JE_LINES A
-- 仕訳残高
        LEFT OUTER JOIN GL_BALANCES B
          ON A.PERIOD_NAME = B.PERIOD_NAME
          AND A.CODE_COMBINATION_ID = B.CODE_COMBINATION_ID
-- AFFコンビネーション
        LEFT OUTER JOIN GL_CODE_COMBINATIONS C
          ON A.CODE_COMBINATION_ID  =  C.CODE_COMBINATION_ID
          AND B.CODE_COMBINATION_ID  =  C.CODE_COMBINATION_ID
-- AFF値の名称(会社)
        LEFT OUTER JOIN FND_VS_VALUES_VL D1
          ON C.SEGMENT1 =  D1.VALUE
-- AFF値の名称(科目)
        LEFT OUTER JOIN FND_VS_VALUES_VL D3
          ON C.SEGMENT3 =  D3.VALUE
-- AFF値の名称(取引先)
        LEFT OUTER JOIN FND_VS_VALUES_VL D4
          ON C.SEGMENT4 =  D4.VALUE
      
    WHERE
          A.PERIOD_NAME >= (:P_PERIOD_NAME_FROM)
      AND A.PERIOD_NAME <= (:P_PERIOD_NAME_TO)
      AND A.STATUS IN (:P_STATUS)
      AND A.LAST_UPDATE_DATE >= (:p_update_date_from)
      AND A.LAST_UPDATE_DATE <= (:p_update_date_to)
      AND SEGMENT1 IN (:P_AFF_SEG1)
      AND SEGMENT3 IN (:P_AFF_SEG3)
      AND SEGMENT4 IN (:P_AFF_SEG4)

    GROUP BY
        A.PERIOD_NAME
      , B.PERIOD_YEAR
      , A.CODE_COMBINATION_ID
      , C.SEGMENT1
      , C.SEGMENT3
      , C.SEGMENT4
      , D1.DESCRIPTION
      , D3.DESCRIPTION
      , D4.DESCRIPTION
      , D3.FLEX_VALUE_ATTRIBUTE3
      )

GROUP BY
    SEGMENT1
  , d1
  , (PERIOD_YEAR - 1)
  , PERIOD_NAME
  , SEGMENT3
  , d3
  , SEGMENT4
  , d4
  , bb
  , DR
  , CR
  , :xdo_user_name
  , TO_CHAR(SYSDATE, 'YYYY/MM/DD')
  , TO_CHAR(SYSDATE, 'HH24:MM:SS')

ORDER BY
    SEGMENT1
  , PERIOD_NAME
  , SEGMENT3
  , SEGMENT4
) main
)

SELECT
''||"連番"
||','||"会社番号"
||','||"会社名"
||','||"年度"
||','||"会計期間"
||','||"勘定科目"
||','||"勘定科目名"
||','||"取引先"
||','||"取引先名"
||','||"期首残高"
||','||"借方金額"
||','||"貸方金額"
||','||"当月残高"
||','||"ユーザー名"
||','||"出力日付"
||','||"出力時刻"
||''
AS CSV_STRING
FROM wrap