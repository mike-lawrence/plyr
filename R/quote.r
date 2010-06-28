#' Quote variables.
#' Create a list of unevaluated expressions for later evaluation
#' 
#' This function is similar to \code{\link{~}} in that it is used to
#' capture the name of variables, not their current value.  This is used
#' throughout plyr to specify the names of variables (or more complicated
#' expressions).
#' 
#' Similar tricks can be performed with \code{\link{substitute}}, but when
#' functions can be called in multiple ways it becomes increasingly tricky
#' to ensure that the values are extracted from the correct frame.  Substitute
#' tricks also make it difficult to program against the functions that use
#' them, while the \code{quoted} class provides 
#' \code{\link{as.quoted.character}} to convert strings to the appropriate
#' data structure.
#' 
#' @param ... unevaluated expressions to be recorded.  Specify names if you want the set the names of the resultant variables
#' @return list of symbol and language primitives
#' @aliases . quoted
#' @export .
#' @name quoted
#' @examples
#' .(a, b, c)
#' .(first = a, second = b, third = c)
#' .(a ^ 2, b - d, log(c))
#' as.quoted(~ a + b + c)
#' as.quoted(a ~ b + c)
#' as.quoted(c("a", "b", "c"))
#' 
#' # Some examples using ddply - look at the column names
#' ddply(mtcars, "cyl", each(nrow, ncol))
#' ddply(mtcars, ~ cyl, each(nrow, ncol))
#' ddply(mtcars, .(cyl), each(nrow, ncol))
#' ddply(mtcars, .(log(cyl)), each(nrow, ncol))
#' ddply(mtcars, .(logcyl = log(cyl)), each(nrow, ncol))
#' ddply(mtcars, .(vs + am), each(nrow, ncol))
#' ddply(mtcars, .(vsam = vs + am), each(nrow, ncol))
. <- function(...) {
  structure(as.list(match.call()[-1]), class="quoted")
}

#' Print quoted variables.
#' Display the \code{\link{str}}ucture of quoted variables
#' 
#' @keywords internal
#' @method print quoted
print.quoted <- function(x, ...) str(x)

#' Compute names of quoted variables.
#' Figure out names of quoted variables, using specified names if they exist, otherwise using \code{\link{make.names}} on the values.
#' 
#' @keywords internal
#' @method names quoted
names.quoted <- function(x) {
  part_names <- make.names(x)
  user_names <- names(unclass(x))

  if (!is.null(user_names)) {
    part_names[user_names != ""] <- user_names[user_names != ""]
  }
  
  part_names
}

#' Evaluate a quoted list of variables.
#' Evaluates quoted variables in specified environment
#' 
#' @return a list
#' @keywords internal
#' @param expr quoted object to evalution
#' @param try if TRUE, return \code{NULL} if evaluation unsuccesful
#' @export
eval.quoted <- function(exprs,  envir = parent.frame(), enclos = if (is.list(envir) || is.pairlist(envir)) parent.frame() else baseenv(), try = FALSE) {
  
  if (is.numeric(exprs)) return(envir[exprs])
  
  if (try) {
    results <- lapply(exprs, failwith(NULL, eval, quiet = TRUE), 
      envir = envir, enclos = enclos)
  } else {
    results <- lapply(exprs, eval, envir = envir, enclos = enclos)
    }
  names(results) <- names(exprs)
  
  results
}

#' Convert input to quoted variables.
#' Convert characters, formulas and calls to quoted .variables
#' 
#' This method is called by default on all plyr functions that take a 
#' \code{.variables} argument, so that equivalent forms can be used anywhere.
#' 
#' Currently conversions exist for character vectors, formulas and 
#' call objects.
#' 
#' @return a list of quoted variables
#' @seealso \code{\link{.}}
#' @aliases as.quoted.call as.quoted.character as.quoted.formula
#'  as.quoted.quoted as.quoted.NULL as.quoted.numeric c.quoted as.quoted
#'  [.quoted
#' @param x input to quote
#' @S3method as.quoted call
#' @S3method as.quoted character
#' @S3method as.quoted formula
#' @S3method as.quoted quoted
#' @S3method as.quoted name
#' @S3method as.quoted NULL
#' @S3method as.quoted numeric
#' @S3method "[" quoted
#' @S3method c quoted
#' @examples
#' as.quoted(c("a", "b", "log(d)"))
#' as.quoted(a ~ b + log(d))
#' @export
as.quoted <- function(x) UseMethod("as.quoted")
as.quoted.call <- function(x) structure(as.list(x)[-1], class="quoted")
as.quoted.character <- function(x) {
  structure(
    lapply(x, function(x) parse(text = x)[[1]]), 
    class="quoted"
  )
}
as.quoted.numeric <- function(x) {
  structure(x, 
    class=c("quoted", "numeric")
  )
}
as.quoted.formula <- function(x) {
  simplify <- function(x) {
    if (length(x) == 2 && x[[1]] == as.name("~")) {
      return(simplify(x[[2]]))
    }
    if (length(x) < 3) return(list(x))
    op <- x[[1]]; a <- x[[2]]; b <- x[[3]]

    if (op == as.name("+") || op == as.name("*") || op == as.name("~")) {
      c(simplify(a), simplify(b))
    } else if (op == as.name("-")) {
      c(simplify(a), bquote(-.(x), list(x=simplify(b))))
    } else {
      list(x)
    }
  }

  structure(
    simplify(x),
    class = "quoted"
  )
}
as.quoted.quoted <- function(x) x
as.quoted.NULL <- function(x) structure(list(), class = "quoted")
as.quoted.name <- function(x) structure(list(x), class = "quoted")

c.quoted <- function(..., recursive = FALSE) {
  structure(NextMethod("c"), class = "quoted")
}

"[.quoted" <- function(x, i, ...) {
  structure(NextMethod("["), class = "quoted")
}

#' Is a formula?
#' Checks if argument is a formula
#' 
#' @keywords internal
#' @export
is.formula <- function(x) inherits(x, "formula")
