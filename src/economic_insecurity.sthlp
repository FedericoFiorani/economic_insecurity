{smcl}
{* *! version 1.0 31oct2025}{...}
{cmd:help economic_insecurity}
{hline}

{title:Title}

{phang}
{bf:economic_insecurity} {hline 2} Computes absolute and relative economic insecurity indices based on year-on-year income changes, using gain/loss weights and exponential discounting.

{title:Syntax}

{p 8 17 2}
{cmd:economic_insecurity}
{it:incomevar [if] [in] [fw aw iw pw]}
{cmd:,}
[{opt id(varname)} {opt time(varname)} {opt loss(real)} {opt gain(real)} {opt discount(real)} {opt periods(integer)} {opt gaps(string)} {opt svy}]

{pstd}
where {it:incomevar} is a numeric variable measuring income, earnings, wealth, or another resource variable observed over time. The {opt time()} variable must be coded as a consecutive numeric sequence within the observation window. For biennial or irregularly spaced panels, users should supply a sequential wave variable (e.g. 1, 2, 3, ...) rather than raw calendar years; see {help economic_insecurity##timenote:Note on time coding}.


{synoptset 20 tabbed}
{synopthdr:options}
{synoptline}
{synopt:{opt id(varname)}}ID variable identifying individuals (panel unit). {opt id()} specifies the individuals in the panel dataset. If {opt id()} is not specified, the program uses the current panel variable from {cmd:tsset} or {cmd:xtset}. If the data are not {cmd:tsset}/{cmd:xtset} and {opt id()} is not specified, the program halts and displays an error message.{p_end}

{synopt:{opt time(varname)}}Time variable (must be numeric and ordered). {opt time()} specifies, for example, the years in the panel dataset. If {opt time()} is not specified, the program uses the current time variable from {cmd:tsset} or {cmd:xtset}. If the data are not {cmd:tsset}/{cmd:xtset} and {opt time()} is not specified, the program halts and displays an error message.{p_end}

{synopt:{opt loss(#)}}Weight applied to income losses (default: 1). {opt loss()} specifies the weight applied to income losses. {opt loss(#)} is optional, requires a real number as input, and its default value is 1.{p_end}

{synopt:{opt gain(#)}}Weight applied to income gains (default: 0.9). {opt gain()} specifies the weight applied to income gains. {opt gain(#)} is optional, requires a real number as input, and its default value is 0.9.{p_end}

{synopt:{opt discount(#)}}Discount factor for past periods (default: 0.5). {opt discount()} specifies the discount factor for past periods. {opt discount(#)} is optional, requires a real number as input, and its default value is 0.5.{p_end}

{synopt:{opt periods(#)}}Time window (default: maximum periods available). {opt periods()} specifies the time window, for example in years, over which {cmd:economic_insecurity} is calculated. {opt periods(#)} is optional, requires an integer number as input. If not specified, the default considers the maximum time span available in the dataset. The value suggested in Bossert and D'Ambrosio (2013) is 5 years.{p_end}

{synopt:{opt gaps(string)}}How to handle interruptions in the income series. Allowed values are {bf:ignore} (default) or {bf:break}. {opt gaps()} specifies how to deal with missing observations. {opt gaps(string)} is optional and requires a string as input, either {bf:ignore} or {bf:break}. In the former case, the code calculates the value of economic insecurity over all available periods, assuming that in periods where the value is missing, the change in the variable of interest is null. In the latter case, if there is a gap in the values and at least one period is missing, the code considers the same person, before and after the gap, as two separate individuals. Below, this treatment is discussed in greater depth.{p_end}

{synopt:{opt svy}}Survey design option. {opt svy} specifies that the survey design previously set with {cmd:svyset} should be applied in the calculation of the aggregate index. Note: the subpop() options takes the argument of the if/in condition directly.{p_end}
{synoptline}



{pstd}
The command accepts frequency, analytic, importance, and sampling weights (not with svy option). If {opt svy} is specified, the data must already be {cmd:svyset}, and weights should be supplied (only) through the survey design settings rather than in the command line. See examples below on how to insert if/in conditions with svy.

{marker timenote}{...}
{phang}
{bf:Note on time coding:}
The command treats adjacent values of {opt time()} as adjacent observation periods. As a result, using raw calendar years for biennial or irregular panels may produce incorrect period counts and unintended gap filling.

{pstd}
Users should therefore create a sequential wave variable and use that variable in {opt time()}. For example:

{phang2}{stata "egen wave = group(year)"}

{pstd}
Then specify {cmd:time(wave)} when running the command.



{title:Description}

{pstd}
{cmd:economic_insecurity} computes an absolute and a relative measure of economic insecurity based on individual income trajectories over time. The insecurity index is calculated by aggregating year-to-year income change, applying a loss weight if income decreases and a gain weight if income increases. These values are optionally discounted over time using an exponential factor, so that more recent periods weight more. The gaps option allows the the user to break the calculation of economic insecurity if a value is missing, or assume no variation of economic insecurity in the missing periods.

{pstd}
The function generates a summary table with the following two indeces:

{p 4 8 2}

{cmd:EI Asolute} — Absolute economic insecurity.{break}
{cmd:EI Relative} — Relative economic insecurity.{break}


{title:Requirements}

{pstd}
Requires Stata 11.0 or newer.
No user-written dependencies are required.

{pstd}
The data must be in long panel format, with one observation per individual and time period. The combination of {opt id()} and {opt time()} must uniquely identify observations.  Data must either be -tsset-/-xtset- beforehand, or the user must specify both -id()- and -time()-. If option -svy- is used, the data must already be -svyset-.

{pstd}
For biennial or irregularly spaced panels, users should create a sequential wave variable and use that variable in {opt time()} rather than raw calendar year.


{title:Examples}

{phang2}{cmd:. webuse nlswork, clear}{p_end}
{phang2}{cmd:. keep idcode year ln_wage age race}{p_end}
{phang2}{cmd:. economic_insecurity ln_wage, id(idcode) time(year) gain(0.2) loss(0.7) discount(0.1) periods(5)}{p_end}
{phang2}{cmd:. economic_insecurity ln_wage if year == 2, id(idcode) time(year) gain(0.2) loss(0.7) discount(0.1) periods(5) svy}{p_end}

{title:Stored results}

{pstd}
{cmd:economic_insecurity} stores the following in {cmd:e()}:

{synoptset 20 tabbed}{...}
{synopthdr:Scalars}
{synoptline}
{synopt:{cmd:e(N_tot)}}number of observations used; available for non-{cmd:svy} estimation{p_end}
{synopt:{cmd:e(N_sample)}}survey sample observations; available with {cmd:svy}{p_end}
{synopt:{cmd:e(N_subsample)}}subpopulation observations; available with {cmd:svy}{p_end}
{synopt:{cmd:e(N_pop)}}population size; available with {cmd:svy}{p_end}
{synopt:{cmd:e(N_subpop)}}subpopulation size; available with {cmd:svy}{p_end}
{synopt:{cmd:e(N_id)}}number of individuals{p_end}
{synopt:{cmd:e(tmin)}}minimum time value in the estimation sample{p_end}
{synopt:{cmd:e(tmax)}}maximum time value in the estimation sample{p_end}
{synopt:{cmd:e(loss)}}loss weight parameter{p_end}
{synopt:{cmd:e(gain)}}gain weight parameter{p_end}
{synopt:{cmd:e(discount)}}discount factor{p_end}
{synopt:{cmd:e(periods)}}number of periods used in the calculation window{p_end}

{synopthdr:Macros}
{synoptline}
{synopt:{cmd:e(cmd)}}{cmd:economic_insecurity}{p_end}
{synopt:{cmd:e(cmdline)}}command as typed{p_end}
{synopt:{cmd:e(depvar)}}income or wealth variable used in the calculation{p_end}
{synopt:{cmd:e(id)}}panel identifier variable{p_end}
{synopt:{cmd:e(time)}}time variable{p_end}
{synopt:{cmd:e(gaps)}}gap treatment option{p_end}
{synopt:{cmd:e(estimator)}}estimation type: unweighted index, weighted index, or {cmd:svy}{p_end}
{synopt:{cmd:e(wtype)}}weight type, if applicable{p_end}
{synopt:{cmd:e(wvar)}}weight variable, if applicable{p_end}
{synopt:{cmd:e(properties)}}{cmd:b V}{p_end}

{synopthdr:Matrices}
{synoptline}
{synopt:{cmd:e(b)}}vector of estimated means for absolute and relative economic insecurity{p_end}
{synopt:{cmd:e(V)}}variance-covariance matrix of the estimates{p_end}
{synopt:{cmd:e(table)}}display table containing mean, standard error, and confidence interval for each measure{p_end}
{synoptline}


{title:References}

{p}
Bossert, W., and C. D'Ambrosio. 2024. Relative measures of economic insecurity. {it:Social Choice and Welfare} 62(3): 571-581.
{break}
Bossert, W., and C. D'Ambrosio. 2013. Measuring economic insecurity. {it:International Economic Review} 54(3): 1017-1030.
{break}
Bossert, W., A. E. Clark, C. D'Ambrosio, and A. Lepinteur. 2023. Economic insecurity and political preferences. {it:Oxford Economic Papers} 75(3): 802-825.
{p_end}

{title:See also}
{phang}{help ei_abs}{p_end}
{phang}{help ei_rel}{p_end}


{title:Authors}

{pstd}
Written by De Sandi & Fiorani, 2025.{p_end}

{title:Contact}

{phang}Federico Fiorani, LISER
{phang}{browse "mailto:federico.fiorani@liser.lu":federico.fiorani@liser.lu}
{p_end}