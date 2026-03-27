{smcl}
{* *! version 1.0.1 25mar2026}{...}
{cmd:help ei_rel}
{hline}

{title:Title}

{phang}
{bf:ei_rel} {hline 2} Generates the individual-level relative economic insecurity index for each observation, consistent with the relative component of {help economic_insecurity:economic_insecurity}.

{title:Syntax}

{p 8 17 2}
{cmd:egen} {it:newvar} {cmd:=} {cmd:ei_rel(}{it:exp}{cmd:)} [{it:if}] [{it:in}] {cmd:,}
[{opt id(varname)} {opt time(varname)} {opt loss(real)} {opt gain(real)}
{opt discount(real)} {opt periods(integer)} {opt gaps(string)}]

{pstd}
where {it:exp} is a numeric variable or expression measuring income, earnings, wealth, or another resource observed over time. The {opt time()} variable must be coded as a consecutive numeric sequence within the observation window. For biennial or irregularly spaced panels, users should supply a sequential wave variable (for example, 1, 2, 3, ...) rather than raw calendar years; see {help ei_rel##timenote:Note on time coding}.

{synoptset 20 tabbed}
{synopthdr:options}
{synoptline}
{synopt:{opt id(varname)}}ID variable identifying individuals (panel unit). If {opt id()} is not specified, the program uses the current panel variable from {cmd:tsset} or {cmd:xtset}. If the data are not {cmd:tsset}/{cmd:xtset} and {opt id()} is not specified, the program halts and displays an error message.{p_end}

{synopt:{opt time(varname)}}Time variable (must be numeric and ordered). If {opt time()} is not specified, the program uses the current time variable from {cmd:tsset} or {cmd:xtset}. If the data are not {cmd:tsset}/{cmd:xtset} and {opt time()} is not specified, the program halts and displays an error message.{p_end}

{synopt:{opt loss(#)}}Weight applied to income losses (default: 1). {opt loss(#)} is optional, requires a real number as input, and must be positive.{p_end}

{synopt:{opt gain(#)}}Weight applied to income gains (default: 0.9). {opt gain(#)} is optional, requires a real number as input, and must be positive.{p_end}

{synopt:{opt discount(#)}}Discount factor for past periods (default: 0.5). {opt discount(#)} is optional, requires a real number as input, and must be positive and smaller than {cmd:min(loss/gain, gain/loss)}.{p_end}

{synopt:{opt periods(#)}}Time window (default: maximum periods available). {opt periods()} specifies the number of periods over which the index is calculated. If not specified, the default uses the full time span in the dataset. At least two periods are required. The value suggested in Bossert and D'Ambrosio (2013) is 5 years.{p_end}

{synopt:{opt gaps(string)}}How to handle interruptions in the income series. Allowed values are {bf:ignore} (default) or {bf:break}. With {bf:ignore}, missing periods inside the calculation window are filled and treated as implying no change in the variable of interest. With {bf:break}, a missing spell interrupts the accumulation of insecurity, so observations before and after the gap are treated as separate continuous series.{p_end}
{synoptline}

{pstd}
{cmd:ei_rel} does not estimate aggregate means and does not accept weights or the {cmd:svy} option. For sample-level estimation, weighted means, standard errors, and confidence intervals, use {help economic_insecurity:economic_insecurity}.

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
{cmd:ei_rel} computes the individual-level relative economic insecurity index at each observation in the requested sample. The calculation mirrors the relative component of {cmd:economic_insecurity}: year-to-year changes in the resource variable are transformed into one-period insecurity values using the relative formulas in the underlying program, and past periods are discounted.

{pstd}
The generated variable is defined only for the observations selected by {it:if} and {it:in}. However, earlier observations for the same individual may still be used internally when needed to recover the requested history window defined by {opt periods()}.

{pstd}
If the output variable already exists, it is replaced.

{title:Requirements}

{pstd}
Requires Stata 11.0 or newer. No user-written dependencies are required.

{pstd}
The data must be in long panel format, with one observation per individual and time period. The combination of {opt id()} and {opt time()} must uniquely identify observations. Data must either be {cmd:tsset}/{cmd:xtset} beforehand, or the user must specify panel identifiers through {opt id()} and {opt time()}.

{pstd}
For biennial or irregularly spaced panels, users should create a sequential wave variable and use that variable in {opt time()} rather than raw calendar year.

{title:Examples}

{phang2}{cmd:. webuse nlswork, clear}{p_end}
{phang2}{cmd:. keep idcode year ln_wage age race}{p_end}
{phang2}{cmd:. xtset idcode year}{p_end}
{phang2}{cmd:. egen ei_r = ei_rel(ln_wage)}{p_end}
{phang2}{cmd:. egen ei_r5 = ei_rel(ln_wage), loss(0.7) gain(0.2) discount(0.1) periods(5)}{p_end}
{phang2}{cmd:. egen ei_r_sel = ei_rel(ln_wage) if year >= 75, id(idcode) time(year) gaps(break)}{p_end}

{title:References}

{phang}
Bossert, W., and C. D'Ambrosio. 2024. Relative measures of economic insecurity. {it:Social Choice and Welfare} 62(3): 571-581.
{p_end}

{title:See also}

{phang}{help ei_abs}{p_end}
{phang}{help economic_insecurity}{p_end}

{title:Authors}

{pstd}
Written by De Sandi & Fiorani, 2025.{p_end}

{title:Contact}

{phang}Federico Fiorani, LISER
{phang}{browse "mailto:federico.fiorani@liser.lu":federico.fiorani@liser.lu}
{p_end}