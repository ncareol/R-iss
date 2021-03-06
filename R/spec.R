# -*- mode: R; indent-tabs-mode: nil; c-basic-offset: 4; tab-width: 4; -*-
# vim: set shiftwidth=4 softtabstop=4 expandtab:
#
# 2013,2014, Copyright University Corporation for Atmospheric Research
# 
# This file is part of the "eolts" package for the R software environment.
# The license and distribution terms for this file may be found in the
# file LICENSE.txt in this package.

testplots <- function()
{
    pdf("/tmp/mapr_spec.pdf",width=8,height=10.5)
    par(mfrow=c(6,4))
    plotspec("%d-%b-%Y_%H-%M-%S.spc.nc")
    dev.off()
    pdf("/tmp/nima_spec.pdf",width=8,height=10.5)
    par(mfrow=c(6,4))
    plotspec("spc_20191001.nc")
    dev.off()
    specdiff(f1="%d-%b-%Y_%H-%M-%S.spc.nc",
        f2="spc_20191001.nc")
}

readspec <- function(file="%d-%b-%Y_%H-%M-%S.spc.nc",
    dir=Sys.getenv("NETCDF_DIR"))
{
    require("eolts")

    start <- dpar("start")
    end <- dpar("end")

    # read a longer period of times, by two hours
    dpar(start=start-3600)
    dpar(end=end+3600)
    on.exit(dpar(start=start, end=end),add=TRUE)

    iod <- netcdf(file=file,dir=dir)
    on.exit(close(iod), add=TRUE)

    #vars <- variables(iod)
    # vars <- variables(iod, all=TRUE)

    # in netcdf, rightmost, last dimension varies most rapidly
    # numSpecAvg:  20
    # numCohInteg:  30
    # interPulsePer  55000 nanosecs
    # gateSpacing  1000 nanosecs
    # heights(time=26,height=40),  325 to 6175 by 150, stored in R as height,time with
    # first dimension, height, varying most rapidly
    # spectraDbs(time=26,height=40,nfft=256), time, height, nfft, stored in R as nfft,height,time

    # fill value = -9999

    time <- readts(iod,"time")
    dpar(start=start, end=end)
    nt <- nrow(time)
    itimes <- positions(time) >= start & positions(time) <= end
    if (!any(itimes)) {
        cat(paste(file,": start time=",format(positions(time[1,])),", end=",
                    format(positions(time[nt,]))),"\n",sep="")

        cat(paste("dpar: start=",format(dpar("start")),", end=",format(dpar("end")),"\n",sep=""))
        stop("times in file not in dpar range")
    }

    time <- time[itimes,,drop=FALSE]

    close(iod)
    iod <- netcdf(file=file,dir=dir)

    spec <- readnc(iod,"spectraDbs")[,,itimes,drop=FALSE]
    hts <- readnc(iod,"heights")[,itimes,drop=FALSE]
    ipp <- readnc(iod,"interPulsePer")[itimes,drop=FALSE] * 1.e-9  # convert from nsec to sec
    nci <- readnc(iod,"numCohIntegs")[itimes,drop=FALSE]
    # freqset <- readnc(iod,"frequency_set")
    freq <- readnc(iod,"frequency") * 1.e6  # convert from MHz to Hz

    gattrs <- readnc(iod)
    reorder <- !is.null(gattrs$history) &&
        length(grep("wppp",gattrs$history,fixed=TRUE)) == 0

    if (reorder) {
        nfft <- dim(spec)[1]
        mid <- trunc(nfft/2)
        spec <- spec[c((mid+2):nfft,1:(mid+1)),,]
    }

    list(spec=spec, hts=hts, ipp=ipp, nci=nci, freq=freq, time=time)
}

readmom <- function(file="moments_%Y%m%d.nc",
    dir=Sys.getenv("NETCDF_DIR"))
{
    require("eolts")

    # options(time.zone="UTC")
    # dpar(start=utime("2019 10 1 23:45"),lenmin=15)
    # dpar(start=utime("2018 10 1 23:45"),lenday=10000)
    iod <- netcdf(file=file,dir=dir)
    on.exit(close(iod), add=TRUE)

    vel <- readnc(iod,"vel")
    specWid <- readnc(iod,"specWid")

    list(vel=vel, specWid=specWid)
}

readfuzzy <- function(file="fuzzy_%Y%m%d.nc",
    dir=Sys.getenv("NETCDF_DIR"))
{
    require("eolts")

    start <- dpar("start")
    end <- dpar("end")

    # read a longer period of times, by two hours
    dpar(start=start-3600)
    dpar(end=end+3600)
    on.exit(dpar(start=start, end=end),add=TRUE)

    iod <- netcdf(file=file,dir=dir)
    on.exit(close(iod), add=TRUE)

    time <- readts(iod,"time")
    dpar(start=start, end=end)
    nt <- nrow(time)
    itimes <- positions(time) >= start & positions(time) <= end
    if (!any(itimes)) {
        cat(paste(file,": start time=",format(positions(time[1,])),", end=",
                    format(positions(time[nt,]))),"\n",sep="")

        cat(paste("dpar: start=",format(dpar("start")),", end=",format(dpar("end")),"\n",sep=""))
        stop("times in file not in dpar range")
    }

    time <- time[itimes,,drop=FALSE]

    close(iod)
    iod <- netcdf(file=file,dir=dir)

    vars <- variables(iod, all=TRUE)

    clutter <- NULL
    if ("clutter_features" %in% vars) 
        clutter <- readnc(iod,"clutter_features")[,,itimes,drop=FALSE]

    doppler <- NULL
    if ("doppler_peak_features" %in% vars) 
        doppler <- readnc(iod,"doppler_peak_features")[,,itimes,drop=FALSE]

    rfi <- NULL
    if ("rfi_features" %in% vars) 
        rfi <- readnc(iod,"rfi_features")[,,itimes,drop=FALSE]

    hts <- readnc(iod,"heights")[,itimes,drop=FALSE]
    ipp <- readnc(iod,"interPulsePer")[itimes,drop=FALSE] * 1.e-9  # convert from nsec to sec
    nci <- readnc(iod,"numCohIntegs")[itimes,drop=FALSE]
    # freqset <- readnc(iod,"frequency_set")
    freq <- readnc(iod,"frequency") * 1.e6  # convert from MHz to Hz
    list(clutter=clutter, doppler=doppler, rfi=rfi,
        hts=hts, ipp=ipp, nci=nci, freq=freq, time=time)
}
nyquistvel <- function(ipp,nci,freq)
{
    # compute nyquist (highest resolvable) velocity in m/s
    # from inter-pulse period in sec, number of coherent
    # integrations and the transmitter frequency in Hz.
    
    1 / (2.0 * nci * ipp) * 2.998e8 / (2.0 * freq)
}

plotspec <- function(
    spcfile="%d-%b-%Y_%H-%M-%S.spc.nc",
    momfile="moments_%Y%m%d.nc",
    dir=Sys.getenv("NETCDF_DIR"),
    xzoom=1.0,          # expansion of velocity scale
    dB=FALSE,           # convert to dB, 10*log10(x) before plotting
    layout=c(1,1),      # nx,ny layout on page
    palette="Heat2",    # color palette
    contour=FALSE,      # whether to add contour lines
    ndev=1,             # how many devices (windows) to ope
    debug=FALSE
    )
{
    # ndev:
    #   1: one device, overplot all plots on same device
    #   N: open up to N new devices

    require("lattice")

    x <- readspec(file=spcfile,dir=dir)

    nfft <- dim(x$spec)[1]
    nhts <- dim(x$hts)[1]
    ntimes <- dim(x$hts)[2]

    if (!is.null(momfile)) xm <- readmom(file=momfile,dir=dir)
    else xm <- NULL

    mid <- trunc(nfft/2)
    vel <- (-mid+1):mid

    # tighten margins
    par(mar=c(2.0,2,1.0,0.2), mgp=c(1.0,0.3,0))

    plots <- list()
    iplot <- 0

    for (it in 1:ntimes) {
        iplot <- iplot + 1

        # If one time was selected in NetCDF file, spec
        # will have 2 dimensions else 3
        if (length(dim(x$spec)) == 3) spec <- x$spec[,,it]
        else spec <- x$spec

        nyvel <- nyquistvel(x$ipp[it], x$nci[it], x$freq)
        df <- nyvel / nfft * 2
        # if (it == 1) browser()
        vel <- -nyvel + df * 0:(nfft-1)
        dhts <- diff(x$hts[, it])
        hmin <- x$hts[1,it] - dhts[1] * 0.30
        hmax <- x$hts[nhts,it] + dhts[length(dhts)] * 1.30

        # panel function to draw spectral lines in levelplot
        spec.lines <- function(...)
        {
            # in this panel function called by levelplot,
            # x,y and z are 1-d vectors of the same length,
            # nfft * nhts, as would be generated by
            #       expand.grid(x=val,y=hts)$z <- spec
            # The velocities are in x, repeated nhts times.
            # The heights are in y, with the first height value
            # repeated nfft times, followed by the second height, etc.
            # In z are the spectra, first the nfft points of
            # the first height, followed by second height, etc.

            args <- list(...)
            # indices of the minimum velocity at the start of each height
            v0indxs <- ((0:(nhts-1)) * nfft) + 1
            # heights. They're repeated, so just grab heights at first velocity
            hts <- args$y[v0indxs]
            dhts <- diff(hts)

            lapply(1:nhts, function(iht) {
                y0 <- args$y[v0indxs][iht]
                dh <- dhts[min(iht,length(dhts))]

                sd <- args$z[v0indxs[iht]:(v0indxs[iht]+nfft-1)]
                ds <- diff(range(sd, na.rm=TRUE))
                sd <- y0 + dh * sd / ds
                panel.lines(vel,sd)

                # if we have moments, plot dopper velocity and width
                if (!is.null(xm)) {
                    dopvel <- xm$vel[iht, it]
                    panel.points(dopvel, y0 + dh * 0.5, pch="+", col="red")
                    velwid <- c(dopvel-0.5*xm$specWid[iht,it],
                        dopvel+0.5*xm$specWid[iht,it])
                    # error bar around doppler velocity
                    xpts <- c(rep(velwid[1],3),rep(velwid[2],3))
                    ypts <- c(y0, y0+dh, y0 + dh * 0.5, y0 + dh * 0.5, y0, y0+dh)
                    panel.lines(xpts, ypts, col="red")
                }
                NULL
            })
            NULL
        }
        pd <- -0.2  # reduce padding between axis titles, labels, tics
        plt <- levelplot(if (dB) 10 * log10(spec) else spec,
            row.values=vel, column.values=x$hts[,it], aspect="fill",
            xlab="vel(m/s)", ylab="heigth(m)",
            xlim=range(vel) / xzoom,
            main=list(label=paste(format(positions(x$time[it,])),
                if (dB) "(dB)" else ""),cex=0.8),
            sub=list(label=paste(spcfile, momfile,sep=", "),cex=0.7),
            panel=function(...) {
                panel.levelplot(...)
                spec.lines(...)
            },
            scales=list(y=list(rot=c(90,-90))),
            # this rotates the colorkey labels, but they are not
            # centered on the tics.  Don't know how to fix that.
            colorkey=list(labels=list(rot=90)),
            col.regions=hcl.colors(100,palette=palette,rev=TRUE),
            contour=contour,
            par.settings=list(axis.components=list(
                bottom=list(pad1=pd,pad2=pd),top=list(pad1=pd,pad2=pd),
                right=list(pad1=pd,pad2=pd),left=list(pad1=pd,pad2=pd)))
        )
        plots[[iplot]] <- plt
    }

    # print the plots, using layout and ndev
    lapply(1:length(plots),function(i) {
        nperpage <- prod(layout)
        ipage <- trunc((i - 1) / nperpage) + 1
        ndevs <- length(dev.list())
        ip <- (i-1) %% nperpage + 1
        if (ipage > ndevs && ipage <= ndev) dev.new()
        else if (ip == 1 && ipage > 1) dev.set()

        lyout <- c(trunc((ip-1)/layout[2])+1,((ip-1)%%layout[2]+1),layout)
        more <- ip < nperpage && i < length(plots)
        if (debug) cat("lyout=",paste(lyout,collapse=","),", more=",more,"\n")
        print(plots[[i]],split=lyout, more=more)
        NULL
    })
    # If the lapply function above returns the value of print(), then
    # the list returned by lapply is identical to the plots list

    # return plot objects
    invisible(plots)
}

plotfuzzy <- function(
    fuzzyfile="fuzzy_%Y%m%d.nc",
    dir=Sys.getenv("NETCDF_DIR"),
    vars=c("clutter","doppler","rfi"),
    xzoom=1.0,          # expansion of velocity scale
    layout=c(1,1),      # nx,ny layout on page
    palette="Heat2",    # color palette
    contour=FALSE,      # whether to add contour lines
    ndev=1,             # how many devices (windows) to ope
    debug=FALSE
    )
{
    # ndev:
    #   1: one device, overplot all plots on same device
    #   N: open up to N new devices

    require("lattice")

    x <- readfuzzy(file=fuzzyfile,dir=dir)

    # tighten margins
    # par(mar=c(2.0,2,1.0,0.2), mgp=c(1.0,0.3,0))

    plots <- list()
    iplot <- 0

    ntimes <- dim(x$hts)[2]

    for (it in 1:ntimes) {
        iplot <- iplot + 1

        for (var in vars) {

            # If one time was selected in NetCDF file, values
            # will have 2 dimensions else 3
            if (length(dim(x[[var]])) == 3) vals <- x[[var]][,,it]
            else vals <- x[[var]]

            nfft <- dim(vals)[1]
            nhts <- dim(x$hts)[1]

            mid <- trunc(nfft/2)
            vel <- (-mid+1):mid


            nyvel <- nyquistvel(x$ipp[it], x$nci[it], x$freq)
            df <- nyvel / nfft * 2
            # if (it == 1) browser()
            vel <- -nyvel + df * 0:(nfft-1)
            dhts <- diff(x$hts[, it])
            hmin <- x$hts[1,it] - dhts[1] * 0.30
            hmax <- x$hts[nhts,it] + dhts[length(dhts)] * 1.30

            pd <- -0.2  # reduce padding between axis titles, labels, tics
            plt <- levelplot(vals,
                row.values=vel, column.values=x$hts[,it], aspect="fill",
                xlab="vel(m/s)", ylab="heigth(m)",
                xlim=range(vel) / xzoom,
                main=list(label=paste(var,format(positions(x$time[it,]))),
                     cex=0.8),
                sub=list(label=fuzzyfile,cex=0.7),
                panel=function(...) {
                    panel.levelplot(...)
                },
                scales=list(y=list(rot=c(90,-90))),
                # this rotates the colorkey labels, but they are not
                # centered on the tics.  Don't know how to fix that.
                colorkey=list(labels=list(rot=90)),
                col.regions=hcl.colors(100,palette=palette,rev=TRUE),
                contour=contour,
                par.settings=list(axis.components=list(
                    bottom=list(pad1=pd,pad2=pd),top=list(pad1=pd,pad2=pd),
                    right=list(pad1=pd,pad2=pd),left=list(pad1=pd,pad2=pd)))
            )
            plots[[iplot]] <- plt
        }
    }

    # print the plots, using layout and ndev
    lapply(1:length(plots),function(i) {
        nperpage <- prod(layout)
        ipage <- trunc((i - 1) / nperpage) + 1
        ndevs <- length(dev.list())
        ip <- (i-1) %% nperpage + 1
        if (ipage > ndevs && ipage <= ndev) dev.new()
        else if (ip == 1 && ipage > 1) dev.set()

        lyout <- c(trunc((ip-1)/layout[2])+1,((ip-1)%%layout[2]+1),layout)
        more <- ip < nperpage && i < length(plots)
        if (debug) cat("lyout=",paste(lyout,collapse=","),", more=",more,"\n")
        print(plots[[i]],split=lyout, more=more)
        NULL
    })
    # If the lapply function above returns the value of print(), then
    # the list returned by lapply is identical to the plots list

    # return plot objects
    invisible(plots)
}

specdiff <- function(f1="%d-%b-%Y_%H-%M-%S.spc.nc",
    f2="spcmom_%Y%m%d.nc",
    dir="/home/maclean/ncar/nima/test")
{

    x1 <- readspec(file=f1,dir=dir)
    x2 <- readspec(file=f2,dir=dir)

    cat(paste(f1,", ",f2,": dimensions= ",
        paste(dim(x1$spec),collapse="x"),"  ",paste(dim(x2$spec),collapse="x"),"\n",sep=""))
    cat(paste(f1,", ",f2,": max diff=",
        max(x1$spec-x2$spec, na.rm=TRUE),"\n",sep=""))
    cat(paste(f1,", ",f2,": NAs equal=",
        all(is.na(x1$spec) == is.na(x2$spec)),"\n",sep=""))
}
