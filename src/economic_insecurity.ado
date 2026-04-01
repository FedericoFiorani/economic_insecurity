*-----------------------------------------------------------*
* Program: economic_insecurity.ado                          *
* Purpose: Compute Economic Insecurity Indices              *
* Authors: De Sandi & Fiorani                               *
*-----------------------------------------------------------*

program define economic_insecurity, eclass
    version 11.0

    syntax varlist(min=1 max=1 numeric) [if] [in] [fw aw iw pw], ///
        [ id(varname) time(varname) loss(real 1) gain(real 0.9) ///
          discount(real 0.5) periods(integer 9999) gaps(string) svy ]

    *------------------------------------------------------------*
    * Store inputs into locals
    *------------------------------------------------------------*
    local income `varlist'
    local id     `id'
    local time   `time'
    local l      `loss'	
    local g      `gain'
    local d      `discount'
    local p      `periods'
	
	local wgt ""
	local wvar ""
	local wtype ""
	local weightinfo "none"

	if "`weight'" != "" {
		local wtype "`weight'"
		local wvar `"`exp'"'
		local wvar : subinstr local wvar "=" "", all
		local wvar : list retokenize wvar
		local wgt [`weight'=`wvar']
		local weightinfo "`wtype' (`wvar')"
	}

    *------------------------------------------------------------*
    * Check existing panel settings
    *------------------------------------------------------------*
    local cur_panel : char _dta[_TSpanel]
    local cur_time  : char _dta[_TStvar]

	* require existing tsset/xtset if id/time are not provided in the command
    if ("`id'" == "" | "`time'" == "") {
        if ("`cur_panel'" == "" | "`cur_time'" == "") {
            di as err "Data are not tsset/xtset. Either tsset/xtset the data or specify id() and time()."
            exit 459
        }
        
		* notify the user if the data using only id or time from the existing panel
		if "`id'" == "" {
			local id "`cur_panel'"
			di as txt "note: id() not specified; using current panel variable `id'"
		}

		if "`time'" == "" {
			local time "`cur_time'"
			di as txt "note: time() not specified; using current time variable `time'"
		}
		
    }
	* warn the user if providing id/time different from the ones already used in their panel
    else {
        if ("`cur_panel'" != "" & "`cur_time'" != "") {
            if ("`cur_panel'" != "`id'" | "`cur_time'" != "`time'") {
                di as txt "note: temporarily overriding current tsset (`cur_panel' `cur_time')"
            }
        }
    }

    *------------------------------------------------------------*
    * Check svy option and its settings
    *------------------------------------------------------------*
    if "`svy'" != "" {
        if "`weight'" != "" {
            di as err "option svy may not be combined with [weight=...]. Use svyset weights/design."
            exit 198
        }
        quietly svyset
        if `"`r(settings)'"' == "" {
            di as err "option svy requires the data to be svyset."
            exit 459
        }
    }

    *------------------------------------------------------------*
    * Preserve dataset and check/calculate periods
    *------------------------------------------------------------*
    preserve

    sort `id' `time'

    * if periods() is omitted, use full time span in data
    if `p' == 9999 {
        quietly summarize `time', meanonly
        local p = r(max) - r(min) + 1
    }

    if `p' <= 1 {
        di as err "error: at least two periods are needed to calculate Economic Insecurity."
        restore
        exit 198
    }

    *------------------------------------------------------------*
    * Build display and calculation masks
	* 1) touse_display: marks the user's requested rows
	* 2) touse_calc: also includes the history necessary to calcu-
	* late the index, by id
    *------------------------------------------------------------*
    tempvar touse_display touse_calc any_disp min_disp max_disp lower_bound time_disp
    gen byte `touse_display' = 0
    replace `touse_display' = 1 `if' `in'

    gen double `time_disp' = `time' if `touse_display'
    by `id': egen `min_disp' = min(`time_disp')
    by `id': egen `max_disp' = max(`time_disp')
    by `id': egen `any_disp' = max(`touse_display')

    gen double `lower_bound' = `min_disp' - (`p' - 1)

    gen byte `touse_calc' = 0
    replace `touse_calc' = 1 if `any_disp' == 1 & ///
        `time' >= `lower_bound' & `time' <= `max_disp'

    *------------------------------------------------------------*
    * Check that id/time uniquely identify observations
    * in the entire dataset
    *------------------------------------------------------------*
	capture isid `id' `time'
    if _rc {
        di as err "Error: `id' `time' do not uniquely identify observations."
        restore
        exit 459
    }

    *------------------------------------------------------------*
    * Validate options: gaps and discount factor
    *------------------------------------------------------------*
    if "`gaps'" == "" local gaps "ignore"
    local gaps = lower("`gaps'")

    if !inlist("`gaps'","ignore","break") {
        di as err "error: gaps() must be 'ignore' (default) or 'break'."
        restore
        exit 198
    }

	if `l' <= 0 | `g' <= 0 {
		di as err "error: loss() and gain() must both be positive."
		restore
		exit 198
	}
	
    if `d' >= min(`g'/`l', `l'/`g') | `d' <= 0 {
        di as err "error: discount factor must be below min(loss/gain, gain/loss) and positive."
        restore
        exit 198
    }

    *------------------------------------------------------------*
    * Set panel if needed
    *------------------------------------------------------------*
    if ("`cur_panel'" != "`id'" | "`cur_time'" != "`time'") {
        capture tsset `id' `time'
        if _rc {
            di as err "error: tsset failed. Check uniqueness of `id' `time' and validity of `time'."
            restore
            exit _rc
        }
    }

    *------------------------------------------------------------*
    * Mark original observations, fill gaps, and update calculation mask
    *------------------------------------------------------------*
    tempvar _orig
    gen byte `_orig' = 1

    tsfill 
	
	tempvar first_calc last_calc
	by `id' (`time'): egen double `first_calc' = min(cond(`touse_calc'==1, `time', .))
	by `id' (`time'): egen double `last_calc'  = max(cond(`touse_calc'==1, `time', .))

	replace `touse_calc' = 1 if missing(`touse_calc') ///
		& !missing(`first_calc') & !missing(`last_calc') ///
		& `time' >= `first_calc' & `time' <= `last_calc'

    *------------------------------------------------------------*
    * Calculate one-period insecurity values
    *------------------------------------------------------------*
    tempvar lag_income insec_abs insec_rel
    gen double `lag_income' = L.`income' if `touse_calc'

    gen double `insec_abs' = .
    gen double `insec_rel' = .
	
	* follow economic insecurity index caveat
	replace `income' = 1 if `income' == 0
	replace `lag_income' = 1 if `lag_income' == 0

    quietly {
        * Gains
        replace `insec_abs' = `g' * (`lag_income' - `income') ///
            if `income' > `lag_income'
        replace `insec_rel' = ln(`lag_income' / `income') ///
            if `income' > `lag_income'

        * Losses
        replace `insec_abs' = `l' * (`lag_income' - `income') ///
            if `income' < `lag_income'
        replace `insec_rel' = (`lag_income' / `income') - 1 ///
            if `income' < `lag_income'
			
        * No change
        replace `insec_abs' = 0 if `income' == `lag_income' & !missing(`lag_income')
        replace `insec_rel' = 0 if `income' == `lag_income' & !missing(`lag_income')
    }

    *------------------------------------------------------------*
    * Create reverse time index within person (1, most recent, to T)
    *------------------------------------------------------------*
    tempvar _t _T rev_index
    by `id' (`time'), sort: gen long `_t' = _n if `touse_calc'
    by `id' (`time'):      gen long `_T' = _N if `touse_calc'
    gen long `rev_index' = `_T' - `_t' + 1 if `touse_calc'
	
    *------------------------------------------------------------*
    * Create reference-specific backward indexes : 
	* For each j from 1 to p, create the "backward count" var, only in calc window
    * this variable is needed to discout with different reference periods
    * the reference period would be when t_index_j = 1
    * this is to later calculate economic insecurity in different periods
    *------------------------------------------------------------*
    forvalues j = 1/`p' {
        tempvar t_index_`j'
        gen long `t_index_`j'' = `rev_index' - (`j' - 1) if `touse_calc'
        replace `t_index_`j'' = . if `rev_index' < `j' & `touse_calc'
    }

    *------------------------------------------------------------*
    * Discount the one-period insecurities
    *------------------------------------------------------------*
    forvalues k = 1/`p' {
        tempvar discounted_abs_`k' discounted_rel_`k'
        gen double `discounted_abs_`k'' = .
        gen double `discounted_rel_`k'' = .

        replace `discounted_abs_`k'' = ///
            `insec_abs' * (`d' ^ (`t_index_`k'' - 1)) ///
            if `t_index_`k'' <= `p' & !missing(`t_index_`k'')

        replace `discounted_rel_`k'' = ///
            `insec_rel' * (`d' ^ (`t_index_`k'' - 1)) ///
            if `t_index_`k'' <= `p' & !missing(`t_index_`k'')
    }

    *------------------------------------------------------------*
    * Cumulative discounted insecurity per person
    *------------------------------------------------------------*
    tempvar present start series
    gen byte `present' = !missing(`income') & !missing(`lag_income')
    by `id' (`time'): gen byte `start' = `present' & (_n == 1 | !`present'[_n-1])
    by `id' (`time'): gen long `series' = sum(`start')

    forvalues z = 1/`p' {
        tempvar total_abs_`z' total_rel_`z'
        gen double `total_abs_`z'' = .
        gen double `total_rel_`z'' = .

        if "`gaps'" == "ignore" { // as default
            by `id' (`time'): replace `total_abs_`z'' = ///
                sum(`discounted_abs_`z'') if `touse_calc'
            by `id' (`time'): replace `total_rel_`z'' = ///
                sum(`discounted_rel_`z'') if `touse_calc'
        }
        else { // when option gap equals break
            bysort `id' `series' (`time'): replace `total_abs_`z'' = ///
                sum(`discounted_abs_`z'') if `touse_calc' & `present'
            bysort `id' `series' (`time'): replace `total_rel_`z'' = ///
                sum(`discounted_rel_`z'') if `touse_calc' & `present'
        }
    }

    *------------------------------------------------------------*
    * Final EI variables for each reference time 1 to p window
    *------------------------------------------------------------*
    tempvar economic_insecurity_abs economic_insecurity_rel
    gen double `economic_insecurity_abs' = .
    gen double `economic_insecurity_rel' = .

    forvalues m = 1/`p' {
        replace `economic_insecurity_abs' = `total_abs_`m'' if `t_index_`m'' == 1
        replace `economic_insecurity_rel' = `total_rel_`m'' if `t_index_`m'' == 1
    }

    * remove observations created by tsfill
    drop if missing(`_orig')

    *------------------------------------------------------------*
    * Estimate means
    *------------------------------------------------------------*
    tempname b V T rt
    local esttype "unweighted index"

    if "`svy'" != "" {
        tempvar yabs yrel
        gen double `yabs' = `economic_insecurity_abs'
        gen double `yrel' = `economic_insecurity_rel'

        quietly svy, subpop(`touse_display'): mean `yabs' `yrel'

        matrix `b'  = e(b)
        matrix `V'  = e(V)
        matrix `rt' = r(table)
		
        scalar N_tot_svy = e(N)
		scalar N_sub_svy = e(N_sub)
		scalar N_pop_svy = e(N_pop)
		scalar N_subpop_svy = e(N_subpop)

        local esttype "svy"
    }
    else {
        quietly mean `economic_insecurity_abs' `economic_insecurity_rel' `wgt' ///
			if `touse_display'

        matrix `b'  = e(b)
        matrix `V'  = e(V)
        matrix `rt' = r(table)
		
        scalar N_tot = e(N)

        if "`wvar'" != "" local esttype "weighted index"
		
    }

    *------------------------------------------------------------*
    * Build display table
    *------------------------------------------------------------*
    matrix `T' = J(2,4,.)
// 	matrix list `rt'
    matrix `T'[1,1] = `rt'[1,1]
    matrix `T'[1,2] = `rt'[2,1]
    matrix `T'[1,3] = `rt'[5,1]
    matrix `T'[1,4] = `rt'[6,1]
    matrix `T'[2,1] = `rt'[1,2]
    matrix `T'[2,2] = `rt'[2,2]
    matrix `T'[2,3] = `rt'[5,2]
    matrix `T'[2,4] = `rt'[6,2]

    matrix colnames `T' = Mean St.Err. CI_Low95% CI_High95%
    matrix rownames `T' = EI_Absolute EI_Relative

    *------------------------------------------------------------*
    * Additional characteristics to store and restore dataset
    *------------------------------------------------------------*
    tempvar tagid
    quietly egen `tagid' = tag(`id') if `touse_display'
    quietly count if `tagid'
    local N_id = r(N)

    quietly summarize `time' if `touse_display', meanonly
    local tmin = r(min)
    local tmax = r(max)

    local cmdline `"`0'"' // raw string argument
    local depname "`income'"

    restore

    *------------------------------------------------------------*
    * Post official e()-results
    *------------------------------------------------------------*
	matrix colnames `b' = EI_Absolute EI_Relative
	matrix rownames `V' = EI_Absolute EI_Relative
	matrix colnames `V' = EI_Absolute EI_Relative

	ereturn post `b' `V'
	ereturn matrix table = `T'

	if "`svy'" != "" {
		ereturn scalar N_sample = N_tot_svy
		ereturn scalar N_subsample = N_sub_svy
		ereturn scalar N_pop = N_pop_svy
		ereturn scalar N_subpop = N_subpop_svy
	}
	else {
		ereturn scalar N_tot      = N_tot
	}
    ereturn scalar N_id     = `N_id'
    ereturn scalar tmin     = `tmin'
    ereturn scalar tmax     = `tmax'
    ereturn scalar loss     = `l'
    ereturn scalar gain     = `g'
    ereturn scalar discount = `d'
    ereturn scalar periods  = `p'

    ereturn local cmd        "economic_insecurity"
    ereturn local cmdline    `"`cmdline'"'
    ereturn local depvar     "`depname'"
    ereturn local id         "`id'"
    ereturn local time       "`time'"
    ereturn local gaps       "`gaps'"
    ereturn local estimator  "`esttype'"
    ereturn local wtype      "`wtype'"
    ereturn local wvar       "`wvar'"
    ereturn local properties "b V"

    *------------------------------------------------------------*
    * Replay
    *------------------------------------------------------------*
	local c1 = 25
	local w  = 15

	di as txt ""
	di as txt "Economic Insecurity Estimation"
	di as txt "{hline 79}"

	di as txt "Sample"
	di as txt "{hline 79}"
	di as txt "Outcome variable:"      _col(`c1') as res %`w's "`e(depvar)'"
	di as txt "ID variable:"           _col(`c1') as res %`w's "`e(id)'"
	di as txt "Time variable:"         _col(`c1') as res %`w's "`e(time)'"

	if "`svy'" != "" {
		di as txt "Survey sample:"        _col(`c1') as res %`w'.0fc e(N_sample)
		di as txt "Survey sample subset:" _col(`c1') as res %`w'.0fc e(N_subsample)
		di as txt "Population:"           _col(`c1') as res %`w'.0fc e(N_pop)
		di as txt "Population subset:"    _col(`c1') as res %`w'.0fc e(N_subpop)
	}
	else {
		di as txt "Observations:"         _col(`c1') as res %`w'.0fc e(N_tot)
	}

	di as txt "Individuals:"           _col(`c1') as res %`w'.0fc e(N_id)
	di as txt "Time span:"             _col(`c1') as res %`w's "`e(tmin)' - `e(tmax)'"

	if "`svy'" != "" {
		di as txt "Weighting:"            _col(`c1') as res %`w's "survey design (svy)"
	}
	else if "`e(wtype)'" != "" {
		di as txt "Weighting:"            _col(`c1') as res %`w's "`e(wtype)' (`e(wvar)')"
	}
	else {
		di as txt "Weighting:"            _col(`c1') as res %`w's "unweighted"
	}

	di as txt ""
	di as txt "Model parameters"
	di as txt "{hline 79}"
	di as txt "Loss weight:"           _col(`c1') as res %`w's "`l'"
	di as txt "Gain weight:"           _col(`c1') as res %`w's "`g'"
	di as txt "Discount factor:"       _col(`c1') as res %`w's "`d'"
	di as txt "Periods:"               _col(`c1') as res %`w's "`p'"
	di as txt "Gap treatment:"         _col(`c1') as res %`w's "`e(gaps)'"

	di as txt ""
	di as txt "Results"
	di as txt "{hline 79}"
	matlist e(table), names border(rows) format(%10.4f)
// 	di as txt "{hline 79}"
	
end