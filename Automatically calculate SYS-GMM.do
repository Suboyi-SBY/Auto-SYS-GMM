****************
*系统GMM滞后组合*
****************

* === 1. 设置滞后范围 (用数字1,2,3,4....替换下面的X) ===
global lag_start X 
global lag_end X

* === 2. 原始数据路径与输出文件路径 ===
local datafile "在此处输入数据路径')"
local outfile "在此处输入输出路径"

* === 3. 变量设置 (请根据自己的实际情况更改) ===
*主代码
local var_main 被解释变量 L.被解释变量 解释变量 控制变量（内生+外生）
*前定变量1
local var_gmm1 L.被解释变量
*前定变量2
local var_gmm2 解释变量
*内生变量
local var_gmm3 内生控制变量
*外生变量
local var_iv 外生控制变量

* === 4. 创建结果存储容器 ===
tempname results
postfile `results' lag1a lag1b lag2a lag2b lag3a lag3b coef pval ar1p ar2p sarganp hansenp using gmm_results_temp.dta, replace

* === 5. 自动循环三组滞后期组合 (请根据自己的实际情况更改gmm 和 collapse) ===
forvalues l1a = $lag_start/$lag_end {
    forvalues l1b = `l1a'/$lag_end {
        forvalues l2a = $lag_start/$lag_end {
            forvalues l2b = `l2a'/$lag_end {
                forvalues l3a = $lag_start/$lag_end {
                    forvalues l3b = `l3a'/$lag_end {

                        di "运行滞后组合：`l1a'-`l1b', `l2a'-`l2b', `l3a'-`l3b'"

                        use "`datafile'", clear

                        quietly {
                            capture xtabond2 `var_main', ///
                                gmm(`var_gmm1', lag(`l1a' `l1b') collapse) ///
                                gmm(`var_gmm2', lag(`l2a' `l2b')) ///
                                gmm(`var_gmm3', lag(`l3a' `l3b') collapse) ///
                                iv(`var_iv') ///
                                robust twostep

                            if _rc != 0 continue

                            matrix b = e(b)
                            local coef = b[1, "L.ptinnvo_w"]

                            quietly test L.ptinnvo_w = 0
                            local pval = r(p)

                            local ar1p = e(ar1p)
                            local ar2p = e(ar2p)
                            local sarganp = e(sarganp)
                            local hansenp = e(hansenp)

                            post `results' (`l1a') (`l1b') (`l2a') (`l2b') (`l3a') (`l3b') (`coef') (`pval') (`ar1p') (`ar2p') (`sarganp') (`hansenp')
                        }
                    }
                }
            }
        }
    }
}

postclose `results'

* === 6. 导出Excel文件 ===
use gmm_results_temp.dta, clear
export excel using "`outfile'", firstrow(variables) replace
di "✅ 完成：GMM滞后组合结果已导出至 `outfile'"

* === 7. 自动筛选最佳组合并显示完整回归命令 ===
use gmm_results_temp.dta, clear
gen valid = (pval < 0.05 & ar1p < 0.1 & ar2p > 0.1 & hansenp > 0.1)
keep if valid

sort pval
if _N == 0 {
    di as error "❌ 未找到满足所有条件的滞后组合。"
    exit 1
}

* 提取最佳组合参数
local best_l1a = lag1a[1]
local best_l1b = lag1b[1]
local best_l2a = lag2a[1]
local best_l2b = lag2b[1]
local best_l3a = lag3a[1]
local best_l3b = lag3b[1]

* 重新运行最佳组合模型并展示命令和结果
use "`datafile'", clear

di as result "✅ 最佳滞后组合："
di "xtabond2 `var_main',"
di "    gmm(`var_gmm1', lag(`best_l1a' `best_l1b') collapse)"
di "    gmm(`var_gmm2', lag(`best_l2a' `best_l2b'))"
di "    gmm(`var_gmm3', lag(`best_l3a' `best_l3b') collapse)"
di "    iv(`var_iv') robust twostep"

xtabond2 `var_main', ///
    gmm(`var_gmm1', lag(`best_l1a' `best_l1b') collapse) ///
    gmm(`var_gmm2', lag(`best_l2a' `best_l2b')) ///
    gmm(`var_gmm3', lag(`best_l3a' `best_l3b') collapse) ///
    iv(`var_iv') robust twostep

