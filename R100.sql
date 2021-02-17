WITH wrap AS (
--wrap is for etext output
SELECT
  ROWNUM "連番", main.*
--rownum should be apart from main select to avoid grouping by
FROM (
SELECT
    A1.SEGMENT1 "会社番号"
    , A1.d1 "会社名"
    , (A1.PERIOD_YEAR - 1) "年度"
    , :P_PERIOD_NAME_FROM "会計期間FROM"
    , :P_PERIOD_NAME_TO "会計期間TO"
    , A1.CURRENCY_CODE "通貨"
    , A1.SEGMENT2 "部門"
    , A1.d2 "部門名"
    , A1.SEGMENT3 "勘定科目"
    , A1.d3 "勘定科目名"
    , A1.SEGMENT4 "取引先"
    , A1.d4 "取引先名"
    , SUM(
        CASE WHEN d1flex3 IN ('A', 'E', 'O') THEN (A1.BBDR - A1.BBCR)
        ELSE (A1.BBDR - A1.BBCR) * (-1)
        END
        ) "前月残高"
    , A1.PNDR "当月借方"
    , A1.PNCR "当月貸方"
    , SUM(
        CASE WHEN d2flex3 IN ('A', 'E', 'O') THEN (A2.BBDR - A2.BBCR)
        ELSE (A2.BBDR - A2.BBCR) * (-1)
        END
        ) "期首残高"
    , A2.PNDR "期中借方"
    , A2.PNCR "期中貸方"
    , SUM(
        CASE WHEN d2flex3 IN ('A', 'E', 'O') THEN (A2.BBDR - A2.BBCR + A2.DR - A2.CR)
        ELSE (A2.BBDR - A2.BBCR + A2.DR - A2.CR) * (-1)
        END
        ) "当月残高"
    , :xdo_user_name "ユーザー名"
    , TO_CHAR(SYSDATE, 'YYYY/MM/DD') "出力日付"
    , TO_CHAR(SYSDATE, 'HH24:MM:SS') "出力時刻"

FROM
-- 仕訳明細(AFF別に集計) for selected periods
    ( SELECT 
        B1.CODE_COMBINATION_ID
        , B1.CURRENCY_CODE
        , B1.PERIOD_YEAR
        , SUM(NVL(B1.PERIOD_NET_DR, 0)) AS PNDR
        , SUM(NVL(B1.PERIOD_NET_CR, 0)) AS PNCR
        , SUM(NVL(B1.BEGIN_BALANCE_DR, 0)) AS BBDR
        , SUM(NVL(B1.BEGIN_BALANCE_CR, 0)) AS BBCR
        , C1.SEGMENT1
        , C1.SEGMENT2
        , C1.SEGMENT3
        , C1.SEGMENT4
        , D1_1.DESCRIPTION AS d1
        , D1_2.DESCRIPTION AS d2
        , D1_3.DESCRIPTION AS d3
        , D1_4.DESCRIPTION AS d4
        , D1_3.FLEX_VALUE_ATTRIBUTE3 as d1flex3

    FROM
        GL_BALANCES B1

        LEFT OUTER JOIN GL_CODE_COMBINATIONS C1
            ON B1.CODE_COMBINATION_ID  =  C1.CODE_COMBINATION_ID
-- AFF値の名称(会社)
        LEFT OUTER JOIN FND_VS_VALUES_VL D1_1
            ON C1.SEGMENT1 =  D1_1.VALUE
-- AFF値の名称(部門)
	    LEFT OUTER JOIN FND_VS_VALUES_VL D1_2
	        ON C1.SEGMENT2 =  D1_2.VALUE
-- AFF値の名称(科目)
        LEFT OUTER JOIN FND_VS_VALUES_VL D1_3
            ON C1.SEGMENT3 =  D1_3.VALUE
-- AFF値の名称(取引先)
        LEFT OUTER JOIN FND_VS_VALUES_VL D1_4
            ON C1.SEGMENT4 =  D1_4.VALUE

    WHERE
        B1.PERIOD_NAME >= (:P_PERIOD_NAME_FROM)
        AND B1.PERIOD_NAME <= (:P_PERIOD_NAME_TO)
        AND B1.LAST_UPDATE_DATE >= (:p_update_date_from)
        AND B1.LAST_UPDATE_DATE <= (:p_update_date_to)
        AND C1.SEGMENT1 IN (:P_AFF_SEG1)
        AND C1.SEGMENT2 IN (:P_AFF_SEG2)
        AND C1.SEGMENT3 IN (:P_AFF_SEG3)
        AND C1.SEGMENT4 IN (:P_AFF_SEG4)

    GROUP BY
            B1.CODE_COMBINATION_ID
          , B1.CURRENCY_CODE
          , B1.PERIOD_YEAR
        , C1.SEGMENT1
        , C1.SEGMENT2
        , C1.SEGMENT3
        , C1.SEGMENT4
        , D1_1.DESCRIPTION 
        , D1_2.DESCRIPTION 
        , D1_3.DESCRIPTION
        , D1_4.DESCRIPTION 
        , D1_3.FLEX_VALUE_ATTRIBUTE3
          
    ) A1

    LEFT OUTER JOIN
-- 仕訳明細(AFF別に集計) for period from beginning of the financial year to selected month
    ( SELECT
        B2.CODE_COMBINATION_ID
        , B2.CURRENCY_CODE
        , B2.PERIOD_YEAR
        , C2.SEGMENT1
        , C2.SEGMENT2
        , C2.SEGMENT3
        , C2.SEGMENT4
        , D2_3.FLEX_VALUE_ATTRIBUTE3 as d2flex3
        , SUM(NVL(gjl2.ENTERED_DR, 0)) AS DR
        , SUM(NVL(gjl2.ENTERED_CR, 0)) AS CR
        , SUM(NVL(B2.PERIOD_NET_DR, 0)) AS PNDR
        , SUM(NVL(B2.PERIOD_NET_CR, 0)) AS PNCR
        , SUM(NVL(B2.BEGIN_BALANCE_DR, 0)) AS BBDR
        , SUM(NVL(B2.BEGIN_BALANCE_CR, 0)) AS BBCR

    FROM
        GL_JE_LINES gjl2
        
        LEFT OUTER JOIN GL_BALANCES B2
            ON gjl2.PERIOD_NAME = B2.PERIOD_NAME
            AND gjl2.CODE_COMBINATION_ID = B2.CODE_COMBINATION_ID

        LEFT OUTER JOIN GL_CODE_COMBINATIONS C2
            ON gjl2.CODE_COMBINATION_ID  =  C2.CODE_COMBINATION_ID
            AND B2.CODE_COMBINATION_ID  =  C2.CODE_COMBINATION_ID
-- AFF値の名称(会社)
	    LEFT OUTER JOIN FND_VS_VALUES_VL D2_1
	        ON C2.SEGMENT1 =  D2_1.VALUE
-- AFF値の名称(部門)
	    LEFT OUTER JOIN FND_VS_VALUES_VL D2_2
	        ON C2.SEGMENT2 =  D2_2.VALUE
-- AFF値の名称(科目)
        LEFT OUTER JOIN FND_VS_VALUES_VL D2_3
            ON C2.SEGMENT3 =  D2_3.VALUE
-- AFF値の名称(取引先)
        LEFT OUTER JOIN FND_VS_VALUES_VL D2_4
            ON C2.SEGMENT4 =  D2_4.VALUE 

    WHERE
        B2.PERIOD_NAME >= (
            SELECT DISTINCT PERIOD_NAME
            FROM GL_PERIOD_STATUSES
            WHERE PERIOD_YEAR = 
                (SELECT DISTINCT PERIOD_YEAR
                FROM GL_PERIOD_STATUSES
                WHERE PERIOD_NAME = (:P_PERIOD_NAME_TO) )
                        AND PERIOD_NUM = 1
        )
        AND B2.PERIOD_NAME <= (:P_PERIOD_NAME_TO)
        AND B2.LAST_UPDATE_DATE >= (:p_update_date_from)
        AND B2.LAST_UPDATE_DATE <= (:p_update_date_to)
        AND C2.SEGMENT1 IN (:P_AFF_SEG1)
        AND C2.SEGMENT2 IN (:P_AFF_SEG2)
        AND C2.SEGMENT3 IN (:P_AFF_SEG3)
        AND C2.SEGMENT4 IN (:P_AFF_SEG4)

    GROUP BY
            B2.CODE_COMBINATION_ID
          , B2.CURRENCY_CODE
          , B2.PERIOD_YEAR
          , C2.SEGMENT1
        , C2.SEGMENT2
        , C2.SEGMENT3
        , C2.SEGMENT4
        , D2_3.FLEX_VALUE_ATTRIBUTE3
    ) A2

ON  A1.CODE_COMBINATION_ID = A2.CODE_COMBINATION_ID

GROUP BY
    A1.SEGMENT1
    , A1.d1
    , (A1.PERIOD_YEAR - 1)
    , :P_PERIOD_NAME_FROM
    , :P_PERIOD_NAME_TO
    , A1.CURRENCY_CODE
    , A1.SEGMENT2
    , A1.d2
    , A1.SEGMENT3
    , A1.d3
    , A1.SEGMENT4
    , A1.d4
    , A1.PNDR 
    , A1.PNCR 
    , A2.PNDR 
    , A2.PNCR
    , :xdo_user_name
    , TO_CHAR(SYSDATE, 'YYYY/MM/DD')
    , TO_CHAR(SYSDATE, 'HH24:MM:SS')

ORDER BY
    A1.SEGMENT1
    , A1.SEGMENT2
    , A1.SEGMENT3
    , A1.SEGMENT4
) main
)

SELECT
''||"連番"
||','||"会社番号"
||','||"会社名"
||','||"年度"
||','||"会計期間FROM"
||','||"会計期間TO"
||','||"通貨"
||','||"部門"
||','||"部門名"
||','||"勘定科目"
||','||"勘定科目名"
||','||"取引先"
||','||"取引先名"
||','||"前月残高"
||','||"当月借方"
||','||"当月貸方"
||','||"期首残高"
||','||"期中借方"
||','||"期中貸方"
||','||"当月残高"
||','||"ユーザー名"
||','||"出力日付"
||','||"出力時刻"
||''
AS CSV_STRING
FROM wrap