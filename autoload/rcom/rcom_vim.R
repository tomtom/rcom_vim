
rcom.rdata <- paste(getwd(), '.rcom.rdata', sep = '/')
if (file.access(rcom.rdata) == 0) {
    sys.load.image(rcom.rdata, TRUE)
} else {
    rcom.rdata <- NULL
}


if (exists('rcom.options') && rcom.options$reuse && 'history' %in% rcom.options$features) {
    rcom.rhistory <- paste(getwd(), '.Rhistory', sep = '/')
    if (file.access(rcom.rhistory) == 0) {
        loadhistory(rcom.rhistory)
    } else {
        rcom.rhistory <- NULL
    }
} else {
    rcom.rhistory <- NULL
}


if (!exists("rcom.quit")) {
    rcom.quit <- function() {
        if (!is.null(rcom.rhistory)) {
            try(savehistory(rcom.rhistory))
        }
        if (!rcom.options$reuse) {
            q()
        }
    }
}


if (!exists("rcom.help")) {
    rcom.help <- function(name) {
        help(name, try.all.packages = TRUE)
    }
}


if (!exists("rcom.keyword")) {
    rcom.keyword <- function(name) {
        if (mode(name) == "function") {
            rcom.help(name)
        } else {
            str(name)
        }
    }
}


if (!exists("rcom.inspect")) {
    rcom.inspect <- function(name) {
        if (exists('gvarbrowser')) {
            gvarbrowser(name)
        } else {
            str(name)
        }
    }
}


if (!exists("rcom.info")) {
    rcom.info <- function(name) {
        switch(name,
            "function" = rcom.help(name),
            rcom.inspect(name)
        )
    }
}

