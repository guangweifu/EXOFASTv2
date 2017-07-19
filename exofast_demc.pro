;+
; NAME:
;   exofast_demc
; PURPOSE:
;   Make NCHAINS independent Markov Chain Monte Carlo chains to fit data
;   and return the parameter distributions.
;
; DESCRIPTION:
;   Begins by determining the correct stepping scale by finding
;   differences in each parameters that yield a delta chi^2 = 1, then
;   uses 5*scale*randomn offsets in each parameter for the starting
;   points of each chain.
;
;   It then begins a Differential Evolution Markov Chain Monte Carlo
;   fit (ter Braak, 2006)
;   http://www.stat.columbia.edu/~gelman/stuff_for_blog/cajo.pdf.  The
;   only slight modification to this basic alogorithm is that we
;   determine the magnitude of the uniform random deviate for each
;   parameter. We have found the dynamic range of our parameters can
;   be large, and thus not well suited to the one-size fits all
;   approach recommended there.
;
;   After taking 5% of MAXSTEPS, the program will estimate how many steps
;   will be necessary to be well-mixed. If it is not expected to be
;   well-mixed before taking the maximum number of steps, it will
;   output a warning and a recommended setting for NTHIN. This should
;   be accurate at the factor of 2-3 level.
;
;   The program stops when the chains are well-mixed, as defined by
;   Ford 2006 (http://adsabs.harvard.edu/abs/2006ApJ...642..505F)
;   using the Gelman-Rubin Statistic and number of independent draws,
;   or when each chain has taken MAXSTEPS, whichever is first.
;
;   Every step in the chain before all chains have crossed below the
;   median chi^2 will be considered the (the "burn-in"), and not used
;   for convergence tests. BURNNDX will specify the index of the first
;   useable step so as not to be biased by the starting criteria.
;
; CALLING SEQUENCE:
;   exofast_demc, bestpars, 'mychi2', pars [,CHI2=, TOFIT=,$
;                 SCALE=, SEED=,RANDOMFUNC=,NTHIN=, MAXSTEPS=,/DONTSTOP,$
;                 NCHAINS=, ANGULAR=,BURNNDX=,/REMOVEBURN]
;
; INPUTS:
;   BESTPARS   - Array of the best-fit parameters. An accurate initial
;                fit is required to find the correct step size. MCMC
;                is not ideal for fitting data, just characterizing
;                the errors.
;   CHI2FUNC   - A string that specifies the name of the user-defined
;                function that calculates the chi^2 of a given
;                parameter set. Required data should be put in a
;                COMMON block. Its calling sequence must be:
;                chi2 = chi2func(pars, determinant=determinant)
;
; OPTIONAL INPUTS:
;   TOFIT      - An array that indexes the parameters to fit. If not
;                specified, all parameters are fit.
;   ANGULAR    - An array that indexes the parameters that are
;                angular (must be in radians). This will enable
;                special ways to calculate the median and convergence
;                statistics, which may otherwise fail. Default is none.
;   SCALE      - An NPARS array containing the stepping scales for
;                each parameter. This is not recommended for normal
;                use. If not specified, it will be automatically
;                determined using EXOFAST_GETMCMCSCALE.
;   NTHIN      - Saves only every NTHINth link in each chain. This
;                is only recommended when the autocorrelation between
;                steps is large and memory management issues may
;                arise. Results will be more accurate the smaller this
;                is -- as long as the chain is well-mixed (pay
;                attention to the warnings).
;   MAXSTEPS   - The maximum number of steps (after thinning) for each
;                chain to take.  The default is 100,000. Take care when
;                increasing this number, as memory allocation issues
;                may arise (especially with 32 bit machines). If the
;                chain is not well-mixed, it is usually better to
;                increase NTHIN instead.
;   NCHAINS    - The number of independent chains to run. The
;                execution time scales ~linearly with this number, and
;                must be at least 3 to calculated convergence
;                statistics. The default is 10. 
;   SEED       - A seed for the random number generator. Do not mix
;                seeds from different random number
;                generators, and do not use several different seeds
;                for the same generator. If you use a random number
;                generator elsewhere, you should call EXOFAST_DEMC with
;                SEED. Default is -systime(/seconds). 
;   RANDOMFUNC - A string for the name of the random number generator
;                function. You can use your own as long as it returns
;                a uniform double precision deviate between 0 and 1,
;                accepts the /NORMAL keyword to generate random
;                gaussian deviates, and can return at least a two
;                dimensional array of deviates. You may also choose
;                between "EXOFAST_RANDOM" (default) or "RANDOMU".
;              - EXOFAST_RANDOM is an IDL wrapper for pg_ran. This is
;                a state of the art, bullet-proof generator with no
;                known statistical flaws, based on the third edition
;                of numerical recipes, pg 342. It is ~120x slower than
;                RANDOMU, though for typical DEMC fits, this accounts
;                for ~1% of the total runtime.
;              - RANDOMU is IDL's built-in, ran1-based generator with a
;                periodicity of ~10^9. ran1 is formally admonished by
;                its author, Numerical Recipes, but shown to give
;                identical results as the state of the art generator
;                See Eastman et. al., 2013 for more details.
;                http://adsabs.harvard.edu/abs/2013PASP..125...83E
;   MAXGR      - The maximum Gelman Rubin statistic that is
;                considered well-mixed (default=1.01)
;   MINTZ      - The minimum number of independent draws that is
;                considered well-mixed (default=1000)
;
; OPTIONAL KEYWORDS:
;   DONTSTOP   - If set, the program will not stop when it is
;                converged, but will instead take MAXSTEPS steps in
;                each chain.
;   REMOVEBURN - If set, the burn-in will be removed in the returned
;                parameter array.
; OUTPUTS:
;   PARS       - NFIT x NSTEPS x NCHAINS array of parameters.
;                NOTE: NSTEPS will be the lesser of when it is
;                converged or MAXSTEPS. 
;   CHI2       - NSTEPS x NCHAINS array with the chi^2 for each set of
;                parameters
;   DERIVED    - An NDERIVED x NSTEPS x NCHAINS array of parameters
;                that are derived during the chi^2 function. To
;                conserve memory, these should be reserved for
;                parameters that cannot be trivially rederived.
;
; SYSTEM VARIABLES:
;   !STOPNOW   - If set, will break the MCMC loop at the next complete
;                step. It must finish the current step, including all
;                NTHIN and NCHAIN evaluations. To set it, type
;                <CONTROL> + C
;                !STOPNOW = 1 
;                .con
;
; REVISION HISTORY:
;   2012/06 - Public Release - Jason Eastman (LCOGT)
;   2012/12 - When parameters aren't mixed, display the index
;             to the (more) static PARS array, not the index to the
;             dynamic TOFIT array.
;           - Removed memory-hungry vestigial code
;   2013/03 - Add GELMANRUBIN and TZ outputs, MAXGR, MINTZ inputs.
;             Added DERIVED output, to return non-trivially derived
;             parameters.
;             Added check for errant chains (stuck in local minima)
;             and discard them if the chains are not well-mixed at the
;             end. This is sketchy, but better than nothing.
;             This was a relatively common failure mode.
;-

pro exofast_demc, bestpars,chi2func,pars,chi2=chi2, tofit=tofit,$
                  scale=scale,seed=seed,randomfunc=randomfunc,$
                  nthin=nthin, maxsteps=maxsteps, dontstop=dontstop,$
                  nchains=nchains, angular=angular,$
                  burnndx=burnndx, removeburn=removeburn, $
                  gelmanrubin=gelmanrubin, tz=tz, maxgr=maxgr, mintz=mintz, $
                  derived=derived, resumendx=resumendx,stretch=stretch, logname=logname

;; default values
if n_elements(maxsteps) eq 0 then maxsteps = 1d5
if n_elements(nthin) eq 0 then nthin = 1L
if n_elements(tofit) eq 0 then tofit = indgen(n_elements(bestpars))
if n_elements(mintz) eq 0 then mintz = 1000d0
if n_elements(maxgr) eq 0 then maxgr = 1.01d0
if n_elements(loglun) eq 0 then loglun = -1

defsysv, '!STOPNOW', 0B
nfit = n_elements(tofit)
!except = 0 ;; don't display errors for NaN and infinity

;; defaults for Differential Evolution MCMC
gamma = 2.38d0/sqrt(2d0*nfit)
if n_elements(nchains) eq 0 then nchains=2d0*nfit

;; use robust generator if estimated steps is large 
;; NOTE: necessarily ignores any random numbers used by chi^2 routine
if n_elements(randomfunc) eq 0 then begin
   nfit = n_elements(tofit)
   ;; number of random deviates required
   ;; Gaussian deviates are made in pairs, and 4/pi must be made for each
   nrand = ((ceil(nfit/2d0)*2d0)*(4d0/!dpi)+1d0)*maxsteps*nchains*nthin
   if nrand le 5d7 then randomfunc = 'randomu' $
   else randomfunc = 'exofast_random'
endif

;; angular must be indexed within tofit to use with gelman-rubin
nang = n_elements(angular)
if nang gt 0 then gelmanangular=intarr(nang)
for i=0, nang-1 do gelmanangular[i] = (where(tofit eq angular[i]))(0)

;; initialize arrays
if n_elements(resumendx) ne 0 then begin
   sz = size(pars)
   nfit = sz[1]
   maxsteps = sz[2]
   nchains = sz[3]
   newpars = pars[*,resumendx,0]
   oldpars = pars[*,resumendx-1,0]
endif else begin
   resumendx = 1L
   pars = dblarr(nfit,maxsteps,nchains)
   chi2 = dblarr(maxsteps,nchains)
   newpars = bestpars
   oldpars = bestpars
endelse
olddet = dblarr(nchains)

;; get the MCMC step scale for each parameter
if n_elements(scale) eq 0 then $
   scale = exofast_getmcmcscale(bestpars,chi2func,tofit=tofit,angular=angular,/skipiter,logname=logname)
if scale[0] eq -1 then begin
   printandlog, 'No scale found',logname
   pars = -1
   return
endif

printandlog, 'Beginning chain initialization', logname
;; initialize each chain
for j=0, nchains-1 do begin
   ;; repeat until a finite chi^2 
   ;; i.e., don't start outside a boundary; you'll never get back
   niter = 0d0
   repeat begin
      ;; start 5 steps from best value. If that's not allowed
      ;; (infinite chi^2), slowly approach 0 steps away from the best value
      ;; niter should never be larger than ~5000
      if j eq 0 then factor = 0d0 else factor = 1d0 ;; first chain starts at best fit
      pars[0:nfit-1,0,j] = bestpars[tofit] + $
                           5d0/exp(niter/1000d)*scale*call_function(randomfunc,seed,nfit,/normal)*factor
      newpars[tofit] = pars[0:nfit-1,0,j]
      ;; find the chi^2
      chi2[0,j] = call_function(chi2func, newpars, determinant=det, derived=dpar)
      pars[*,0,j]=newpars[tofit] ;; in case chi2 function changes pars
      olddet[j] = det
      niter += 1

   endrep until finite(chi2[0,j])
   if n_elements(dpar) ne 0 then begin
      if j eq 0 then begin
         nderived = n_elements(dpar)
         derived = dblarr(nderived,maxsteps,nchains)
      endif
      derived[*,0,j] = dpar
   endif

endfor
printandlog, 'Done initializing chains', logname
printandlog, '', logname

if n_elements(dpar) ne 0 then oldderived = reform(derived[*,0,*],nderived,nchains)

a = 2d0 ;; a > 1

nextrecalc = 100L
npass = 1L 
nstop = 0L
naccept = 1d0
tz0 = 0d0
tzsteps = 0L
alreadywarned = 0L
t0 = systime(/seconds)
minburnndx = 0L

idealacceptancerate = 0.23d0 ;; automatically scale "a" to get ideal acceptance rate

;; start MCMC chain
for i=resumendx,maxsteps-1L do begin
   for j=0L, nchains-1L do begin
      
      oldpars[tofit] = pars[*,i-1,j]
      oldchi2 = chi2[i-1,j]
            
      ;; automatically thin the chain (saves memory)
      for k=0L, nthin-1L do begin
         
         if keyword_set(stretch) then begin
            ;; affine invariant "stretch move" step 
            ;; see Goodman & Weare, 2010 (G10), eq 7 
            ;; http://msp.org/camcos/2010/5-1/camcos-v5-n1-p04-p.pdf
            repeat r1=floor(call_function(randomfunc,seed)*(nchains)) $
            until r1 ne j ;; a random chain

            ;; a random number between 1/a and a, weighted toward lower
            ;; values to satisfy the symmetry condition (G10, eq 8)
            z = ((a-1d0)*call_function(randomfunc,seed) + 1d0)^2d0/2d0 
            
            ;; use the most recent step (Goodman, pg 69)
            if r1 lt j then ndx = i else ndx = i-1 
            ;; define the new step (eq 7 in G10)
            newpars[tofit] = pars[*,ndx,r1] + z*(oldpars[tofit]-pars[*,ndx,r1])
            fac = z^(nfit-1) ;; GW10, last equation, pg 70
         endif else begin
            ;; differential evolution mcmc step (Ter Braak, 2006)
            repeat r1=floor(call_function(randomfunc,seed)*(nchains)) $
            until r1 ne j ;; a random chain
            repeat r2=floor(call_function(randomfunc,seed)*(nchains)) $
            until r2 ne j and r2 ne r1 ;; another random chain
            newpars[tofit] = oldpars[tofit] + $ 
                             gamma*(pars[*,i-1,r1]-pars[*,i-1,r2]) + $
                             (call_function(randomfunc,seed,nfit)-0.5d0)*scale/10d0
            fac = 1d0
         endelse
 

         ;; calculate the chi^2 of the new step
         newchi2 = call_function(chi2func,newpars,determinant=det,derived=dpar)
         C = fac*olddet[j]/det*exp((oldchi2 - newchi2)/2d0)

         ;; accept the step; update values
         if call_function(randomfunc,seed) lt C then begin
            naccept++
            olddet[j] = det
            oldpars = newpars
            oldchi2 = newchi2
            if n_elements(dpar) ne 0 then oldderived[*,j] = dpar
         endif ;; else keep previous values
         
      endfor
      
      ;; update the link in the chain
      pars[*,i,j] = oldpars[tofit]
      chi2[i,j] = oldchi2
      if n_elements(dpar) ne 0 then derived[*,i,j] = oldderived[*,j]
      
   endfor

   if !STOPNOW NE !NULL AND !STOPNOW EQ 1 then break

   ;; Test for convergence as outlined in Ford 2006
   ;; must be converged for 6 consecutive passes
   ;; tz > 1000 and Gelman-Rubin < 1.01 => converged 
   if i eq nextrecalc then begin
      ;; discard the burn-in (the first point at which all chains
      ;; have had at least one chi^2 lower than the median chi^2)

      ;; the minimum chi2 of each chain
      minchi2 = min(chi2[0:i,*],dimension=1)

      ;; the median chi2 of the best chain
      medchi2 = min(median(chi2[0.1*i:i,*],dimension=1))

      ;; good chains must have some values below this median
      goodchains = where(minchi2 lt medchi2,ngood)
      if ngood lt 3 then begin
         goodchains = lindgen(nchains)
         ngood = nchains
      endif

      burnndx = 0L
      for j=0L, ngood-1 do begin
         tmpndx = (where(chi2[0:i,goodchains[j]] lt medchi2))(0)
         if tmpndx gt burnndx then burnndx = tmpndx
      endfor
      ;; allows Gelman-Rubin calculation if one chain is being problematic
      burnndx = burnndx < (i-3) 
      
      ;; calculate the Gelman-Rubin statistic (remove burn-in)
      converged = exofast_gelmanrubin(pars[0:nfit-1,burnndx:i,goodchains],$
                                      gelmanrubin,tz,angular=gelmanangular,$
                                      mintz=mintz,maxgr=maxgr)
      
      ;; estimate the number of steps it will take until it is converged
      tz0 = [tz0,min(tz)]
      tzsteps = [tzsteps,i]
      ntz = n_elements(tz0)
      if not alreadywarned then begin
         if i gt maxsteps/20d0 and ntz gt 3 then begin
            ;; fit a line to the number of independent draws
            coeffs = poly_fit(tzsteps[1:ntz-1],tz0[1:ntz-1],1,yfit=fit)
            
            ;; extrapolate to 2000, when it'll be considered converged 
            ;; MINTZ is considered converged, but this is far from exact...
            stepstoconvergence = (2d0*mintz - coeffs[0])/coeffs[1]
            
            ;; if it won't be converged, warn the user
            if stepstoconvergence gt maxsteps then begin
               bestnthin = round(stepstoconvergence*nthin/maxsteps)
               printandlog,'WARNING: The chain is not expected to be well-mixed; '+$
                       'set NTHIN to >~ ' + strtrim(bestnthin,2) + ' to fix', logname
            endif else if stepstoconvergence le 0 then begin
               printandlog, 'WARNING: The chains are not mixing. This may be a while.', logname
            endif else printandlog, string(stepstoconvergence*50d0/maxsteps,$
                                              format='("EXOFAST_DEMC: The chain is expected to be ' + $
                                              'well-mixed after ",i2,"% completed     ")'), logname
            alreadywarned = 1 ;; only display message once
         endif
      endif
      
      ;; must pass 6 consecutive times
      if converged then begin
         if nstop eq 0 then nstop = i
         nextrecalc = long(nstop/(1.d0-npass/100.d0))
         npass++
         if npass eq 6 then begin
            if not keyword_set(dontstop) then break
            nextrecalc = maxsteps
         endif
      endif else begin
         nextrecalc = long(i/0.9d0)
         nstop = 0L
         npass = 1L
      endelse
   endif
   
   ;; print the progress, cumulative acceptance rate, and time remaining
   acceptancerate = strtrim(string(naccept/double(i*nchains*nthin)*100,$
                                   format='(f6.2)'),2)

   ;; Limited testing suggests this is unnecessary (counter-productive, even)
;   ;; tune the stretch scale (a) to achieve the optimal acceptance rate (~23%)
;   ;; if we've taken fewer than 5% of the total steps
;   if double(i)/maxsteps lt 0.05 and keyword_set(stretch) then begin 
;      if naccept/(double(i*nchains*nthin)) lt idealacceptancerate*0.75 or $
;         naccept/(double(i*nchains*nthin)) gt idealacceptancerate*1.25 then begin
;
;         printandlog, '', logname
;         printandlog, 'Acceptance rate (' + acceptancerate + ') not ideal -- scaling stretch scale from ' + strtrim(a,2) + ' to ' + strtrim(a*naccept/(double(i*nchains*nthin))/idealacceptancerate,2),logname
;         a = a*naccept/(double(i*nchains*nthin))/idealacceptancerate
;
;         ;; more continous scaling
;         if accepted then a += (1d0-idealacceptancerate)/i $
;         else a -= idealacceptancerate/i
;
;         minburnndx = i
;      endif
;   endif

   timeleft = (systime(/seconds)-t0)*(maxsteps/(i+1d)-1d)
   units = ' seconds '
   if timeleft gt 60 then begin
      timeleft /= 60
      units = ' minutes '
      if timeleft gt 60 then begin
         timeleft /= 60
         units = ' hours   '
         if timeleft gt 24 then begin
            timeleft /= 24
            units = ' days    '
         endif
      endif
   endif

   ;; Windows formatting is messy, only output every 1%
   if !version.os_family ne 'Windows' or $
      i mod round(maxsteps/1000d0) eq 0 then begin
      timeleft = strtrim(string(timeleft,format='(f255.2)'),2)
      format='("EXOFAST_DEMC:",f6.2,"% done; acceptance rate = ",a,"%; ' + $ 
             'time left: ",a,a,$,%"\r")'
      print, 100.d0*(i+1)/maxsteps,acceptancerate,timeleft,units, format=format
      if i eq resumendx then printandlog, string(100.d0*(i+1)/maxsteps,acceptancerate,timeleft,units, format=format), logname
   endif

endfor
printandlog, '', logname ;; don't overwrite the final line
printandlog, '', logname ;; now just add a space

;; it doesn't necessarily stop at MAXSTEPS if it was interrupted or converged early
nstop = i-1L

;; the minimum chi2 of each chain
minchi2 = min(chi2[0:nstop,*],dimension=1)

;; the median chi2 of the best chain
medchi2 = min(median(chi2[0.1*nstop:nstop,*],dimension=1))

;; good chains must have some values below this median
goodchains = where(minchi2 lt medchi2,ngood)

burnndx = minburnndx
for j=0L, ngood-1 do begin
   tmpndx = (where(chi2[0:nstop,goodchains[j]] lt medchi2))(0)
   if tmpndx gt burnndx then burnndx = tmpndx
endfor
;; allows Gelman-Rubin calculation if one chain is being problematic
burnndx = burnndx < (i-3) 

;; if there are bad chains, is it better without them?
;; (it usually is unless it's a very short run)
if ngood ne nchains or npass ne 6 then begin
   ;; are all the chains mixed?
   converged = exofast_gelmanrubin(pars[0:nfit-1,burnndx:nstop,*],$
                                   gelmanrubin,tz,angular=gelmanangular, $
                                   maxgr=maxgr, mintz=mintz)
   
   if ngood gt 2 then begin
      converged2 = exofast_gelmanrubin(pars[0:nfit-1,burnndx:nstop,goodchains],$
                                       gelmanrubin2,tz2,angular=gelmanangular, $
                                       maxgr=maxgr, mintz=mintz)
      bad = where(tz lt mintz or gelmanrubin gt maxgr)
      if bad[0] ne -1 then extrabad = where(tz2[bad] lt tz[bad] or $
                            gelmanrubin2[bad] gt gelmanrubin[bad]) $
      else extrabad = -1

   endif else begin
      bad = where(tz lt mintz or gelmanrubin gt maxgr)
      extrabad = -1
   endelse

   if bad[0] eq -1 then begin
      if npass ne 6 then printandlog, 'Chains are marginally well-mixed',logname $
      else printandlog,'All chains are mixed, but some chains never got below '+$
            'the median chi^2. Is this even possible?',logname
   endif else if extrabad[0] eq -1 and ngood ne nchains and ngood gt 2 then begin
      ;; without errant chains, it's better
      printandlog, 'Discarding ' + strtrim(round(nchains-ngood),2) + '/'+$
              strtrim(round(nchains),2) + ' chains stuck in local minima.', logname
      pars = pars[*,*,goodchains]
      chi2 = chi2[*,goodchains]
      if n_elements(derived) ne 0 then derived = derived[*,*,goodchains]
      nchains = ngood
      tz = tz2
      gelmanrubin = gelmanrubin2
      bad = where(tz lt mintz or gelmanrubin gt maxgr)
      if not converged2 then begin
         printandlog, 'Remaining chains are still not mixed. Must run longer.', logname
         printandlog, '       Parameter  Gelman-Rubin Independent Draws',logname
         for i=0L, n_elements(bad)-1 do printandlog, tofit[bad[i]], gelmanrubin[bad[i]],tz[bad[i]],logname
      endif
   endif else begin
      printandlog, 'No obviously-errant chains. Must run longer.', logname
      printandlog, '       Parameter  Gelman-Rubin Independent Draws',logname
      for i=0L, n_elements(bad)-1 do printandlog, tofit[bad[i]], gelmanrubin[bad[i]],tz[bad[i]], logname
   endelse
endif

;; remove the burn-in/uncalculated parameters
;; keep them by default so people can do their own analysis
if keyword_set(removeburn) then begin
   pars = pars[*,burnndx:nstop,*]
   chi2 = chi2[burnndx:nstop,*]
   if n_elements(derived) ne 0 then derived = derived[*,burnndx:nstop,*]
endif else begin
   pars = pars[*,0:nstop,*]
   chi2 = chi2[0:nstop,*]
   if n_elements(derived) ne 0 then derived = derived[*,0:nstop,*]
endelse

;; calculate the runtime and units
runtime = systime(/seconds)-t0
units = ' seconds'
if runtime gt 60 then begin
   runtime /= 60
   units = ' minutes'
   if runtime gt 60 then begin
      runtime /= 60
      units = ' hours'
      if runtime gt 24 then begin
         runtime /= 24
         units = ' days'
      endif
   endif
endif

runtime = strtrim(string(runtime,format='(f100.2)'),2)

format = '("EXOFAST_DEMC: done in ",a,a,"; took ",a,"% of trial steps")'
printandlog, string(runtime, units, acceptancerate, format=format), logname

end

    
