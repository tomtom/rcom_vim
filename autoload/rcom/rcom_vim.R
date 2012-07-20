
rcom.rdata <- paste(getwd(), '.rcom.rdata', sep = '/')
if (file.access(rcom.rdata) == 0) {
    sys.load.image(rcom.rdata, TRUE)
} else {
    rcom.rdata <- NULL
}


if (all((c('reuse', 'history') %in% rcom.options$features) == c(FALSE, TRUE))) {
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
        if (!'reuse' %in% rcom.options$features) {
            q()
        }
    }
}


if (!exists("rcom.help")) {
    rcom.help <- function(name.string) {
        help((name.string), try.all.packages = TRUE)
    }
}


if (!exists("rcom.complete")) {
    rcom.complete <- function(pattern, mode = '') {
        completions <- switch(mode,
            tskeleton = sapply(apropos(pattern), function(t) {
                if (try(is.function(eval.parent(parse(text = t))), silent = TRUE) == TRUE)
                    sprintf("%s(<+CURSOR+>)", t)
                else
                    t
                }),
            apropos(pattern)
        )
        paste(completions, collapse = "\n")
    }
}


if (!exists("rcom.keyword")) {
    rcom.keyword <- function(name, name.string) {
        if (name.string == '') {
            rcom.help(name)
        } else if (mode(name) == 'function') {
            rcom.help(name.string)
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
        if (mode(name) == 'function') {
            rcom.help(name)
        } else {
            rcom.inspect(name)
        }
    }
}

