*-----------------------------------------------------------*
* Program: _gei_abs.ado                                     *
* Purpose: Generate Absolute Economic Insecurity Variable   *
* Authors: De Sandi & Fiorani                               *
*-----------------------------------------------------------*

program define _gei_abs
    version 11.0

    syntax newvarname =/exp [if] [in], ///
        [ id(varname) time(varname) ///
          loss(real 1) gain(real 0.9) discount(real 0.5) ///
          periods(integer 9999) gaps(string) ]

    tempfile _ei_a

    *------------------------------------------------------------*
    * Store inputs into locals
    *------------------------------------------------------------*
    local outvar `varlist'
    local id    `id'
    local time  `time'
    local l     `loss'
    local g     `gain'
    local d     `discount'
    local p     `periods'

    *------------------------------------------------------------*
    * Check existing panel settings
    *------------------------------------------------------------*
    local cur_panel : char _dta[_TSpanel]
    local cur_time  : char _dta[_TStvar]

    if ("`id'" == "" | "`time'" == "") {
        if ("`cur_panel'" == "" | "`cur_time'" == "") {
            di as err "Data are not tsset/xtset. Either tsset/xtset the data or specify id() and time()."
            exit 459
        }

        if "`id'" == "" {
            local id "`cur_panel'"
            di as txt "note: id() not specified; using current panel variable `id'"
        }

        if "`time'" == "" {
            local time "`cur_time'"
            di as txt "note: time() not specified; using current time variable `time'"
        }
    }
    else {
        if ("`cur_panel'" != "" & "`cur_time'" != "") {
            if ("`cur_panel'" != "`id'" | "`cur_time'" != "`time'") {
                di as txt "note: temporarily overriding current tsset (`cur_panel' `cur_time')"
            }
        }
    }

    *------------------------------------------------------------*
    * Preserve dataset
    *------------------------------------------------------------*
    preserve

    * Evaluate expression into a temp variable
    tempvar income
    gen double `income' = `exp'

    sort `id' `time'

    *------------------------------------------------------------*
    * periods() default and validation
    *------------------------------------------------------------*
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
    * Check uniqueness
    *------------------------------------------------------------*
    capture isid `id' `time'
    if _rc {
        di as err "error: `id' `time' do not uniquely identify observations."
        restore
        exit 459
    }

    *------------------------------------------------------------*
    * Validate options
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
    * Build display and calculation masks
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
    * Mark original observations, fill gaps, and update calc mask
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
    * Calculate one-period absolute insecurity
    *------------------------------------------------------------*
    tempvar lag_income insec_abs
    gen double `lag_income' = L.`income' if `touse_calc'

    gen double `insec_abs' = .

    * Match economic_insecurity behavior exactly
    replace `income' = 1 if `income' == 0
	replace `lag_income' = 1 if `lag_income' == 0

    quietly {
        * Gains
        replace `insec_abs' = `g' * (`lag_income' - `income') ///
            if `income' > `lag_income'

        * Losses
        replace `insec_abs' = `l' * (`lag_income' - `income') ///
            if `income' < `lag_income'

        * No change
        replace `insec_abs' = 0 if `income' == `lag_income' & !missing(`lag_income')
    }

    *------------------------------------------------------------*
    * Create reverse time index within calc window
    *------------------------------------------------------------*
	tempvar _t _T rev_index
    by `id' (`time'), sort: gen long `_t' = _n if `touse_calc'
    by `id' (`time'):      gen long `_T' = _N if `touse_calc'
    gen long `rev_index' = `_T' - `_t' + 1 if `touse_calc'

    *------------------------------------------------------------*
    * Create reference-specific backward indexes
    *------------------------------------------------------------*
    forvalues j = 1/`p' {
        tempvar t_index_`j'
        gen long `t_index_`j'' = `rev_index' - (`j' - 1) if `touse_calc'
        replace `t_index_`j'' = . if `rev_index' < `j' & `touse_calc'
    }

    *------------------------------------------------------------*
    * Discount one-period absolute insecurity
    *------------------------------------------------------------*
    forvalues k = 1/`p' {
        tempvar discounted_abs_`k'
        gen double `discounted_abs_`k'' = .

        replace `discounted_abs_`k'' = ///
            `insec_abs' * (`d' ^ (`t_index_`k'' - 1)) ///
            if `t_index_`k'' <= `p' & !missing(`t_index_`k'')
    }

    *------------------------------------------------------------*
    * Cumulative discounted insecurity per person over time within calc window
    *------------------------------------------------------------*
    tempvar present start series
    gen byte `present' = !missing(`income') & !missing(`lag_income')
    by `id' (`time'): gen byte `start' = `present' & (_n == 1 | !`present'[_n-1])
    by `id' (`time'): gen long `series' = sum(`start')

    forvalues z = 1/`p' {
        tempvar total_abs_`z'
        gen double `total_abs_`z'' = .

        if "`gaps'" == "ignore" { // as default
            by `id' (`time'): replace `total_abs_`z'' = ///
                sum(`discounted_abs_`z'') if `touse_calc'
        }
        else { // when option gap equals break
            bysort `id' `series' (`time'): replace `total_abs_`z'' = ///
                sum(`discounted_abs_`z'') if `touse_calc' & `present'
        }
    }

    *------------------------------------------------------------*
    * Final EI variable for each reference time
    *------------------------------------------------------------*
    gen double `outvar' = .

    forvalues m = 1/`p' {
        replace `outvar' = `total_abs_`m'' if `t_index_`m'' == 1
    }

    * remove observations created by tsfill
    drop if missing(`_orig')

    * keep only rows requested by user
    keep `id' `time' `outvar' `touse_display'
    drop if !`touse_display'
    drop `touse_display'

    save "`_ei_a'", replace
    restore

    *------------------------------------------------------------*
    * Merge generated variable back
    *------------------------------------------------------------*
    capture confirm variable `outvar'
    if !_rc {
		di as txt "note: variable `outvar' already exists; replacing it"
        drop `outvar'
    }

    merge 1:1 `id' `time' using "`_ei_a'", keep(match master) nogen noreport
	
end