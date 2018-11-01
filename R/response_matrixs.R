
model_response_class <- function(name, value=NA, fit=NA)
{
  mr <- structure(list(name=name, value=value, fit=fit),
                  class = "modelResponse")
  return(mr)
}

print.modelResponse <- function(mr)
{
  z <- sprintf("%s = %f\n", mr$name, mr$value)
  cat(z)
}


batch_response_class <- function(name, value=NA, control=NA, treatment=NA)
{
  br <- structure(list(name=name, value=value, control=control, treatment=treatment),
                 class = "batchResponse")
  return(br)
}

print.batchResponse <- function(br)
{
  z <- sprintf("%s = %f\ncontrol = %f\ntreatment = %f\n", br$name, br$value,
               br$control$value, br$treatment$value)
  cat(z)
}



#' \code{setResponse} sets response of an Xeva object
#'
#' @param object Xeva object
#' @param res.measure response measure, multipal measure allowed
#' @param min.time default \strong{10} days. Used for \emph{mRECIST} computation
#' @param treatment.only Default \code{FALSE}. If TRUE give data only for non-zero dose periode (if dose data avalible)
#' @param max.time maximum time for data
#' @param vol.normal default \code{TRUE} will use
#' @param impute.value default \code{FALSE}. If TRUE will impute the values
#' @param concurrent.time default \code{FALSE}. If TRUE will cut the batch data such that control and treatment will end at same time point
#' @param verbose default \code{TRUE} will print infromation
#'
#' @return  returns updated Xeva object
#'
#' @examples
#' data(brca)
#' brca  <- setResponse(brca, res.measure = c("mRECIST"))
#' @export
setResponse <- function(object, res.measure=c("mRECIST", "slope", "AUC", "angle", "abc"),
                        min.time=10, treatment.only=TRUE, max.time=NULL,
                        vol.normal=TRUE, impute.value=TRUE, concurrent.time =TRUE,
                        verbose=TRUE)
{
  sen <- slot(object, "sensitivity")

  ###--------compute mRECIST ---------------------------------------------------
  if(any(c("mRECIST", "best.response", "best.average.response") %in% res.measure))
  {
    vl2compute <- c("mRECIST", "best.response", "best.response.time",
                    "best.average.response", "best.average.response.time")
    sen$model[, vl2compute[!(vl2compute%in%colnames(sen$model))]] <- NA

    for(mid in modelInfo(object)$model.id)
    {
      mr <- response(object, model.id=mid, res.measure="mRECIST",
                     treatment.only=treatment.only, max.time=max.time,
                     impute.value=impute.value, min.time=min.time,
                     concurrent.time=FALSE, verbose=verbose)
      for(si in vl2compute)
      { sen$model[mid, si] <- mr[[si]] }
    }
  }

  ###--------compute slope -----------------------------------------------------
  if("slope" %in% res.measure)
  {
    sen$model[, "slope"] <- NA
    for(mid in modelInfo(object)$model.id)
    {
      sl <- response(object, model.id=mid, res.measure="slope",
                     treatment.only=treatment.only, max.time=max.time,
                     impute.value=impute.value, min.time=min.time,
                     concurrent.time=FALSE, verbose=verbose)
      sen$model[mid, "slope"] <- sl$value #$slope
    }
  }

  ###--------compute AUC -------------------------------------------------------

  if("AUC" %in% res.measure)
  {
    sen$model[, "AUC"] <- NA
    for(mid in modelInfo(object)$model.id)
    {
      auc <- response(object, model.id=mid, res.measure="AUC",
                     treatment.only=treatment.only, max.time=max.time,
                     impute.value=impute.value, min.time=min.time,
                     concurrent.time=FALSE, verbose=verbose)
      sen$model[mid, "AUC"] <- auc$value
    }
  }

  ###--------compute doubling time ---------------------------------------------


  ##----------------------------------------------------------------------------
  ##-----------------for batch -------------------------------------------------

  ###--------compute angle for batch -------------------------------------------
  if("angle" %in% res.measure)
  {
    sen$batch[, c("slope.control", "slope.treatment", "angle")] <- NA
    #for(bid in batchNames(object))
    for(bid in batchInfo(object))
    {
      sl <- response(object, batch = bid, res.measure="angle",
                     treatment.only=treatment.only, max.time=max.time,
                     impute.value=impute.value, min.time=min.time,
                     concurrent.time=concurrent.time, verbose=verbose)
      sen$batch[bid, c("slope.control", "slope.treatment", "angle")] <-
        c(sl$control$value, sl$treatment$value, sl$value)
    }
  }

  ###--------compute abc for batch ---------------------------------------------
  if("abc" %in% res.measure)
  {
    sen$batch[, c("auc.control", "auc.treatment", "abc")] <- NA
    #for(bid in batchNames(object))
    for(bid in batchInfo(object))
    {
      sl <- response(object, batch = bid, res.measure="abc",
                     treatment.only=treatment.only, max.time=max.time,
                     impute.value=impute.value, min.time=min.time,
                     concurrent.time=concurrent.time, verbose=verbose)
      sen$batch[bid, c("auc.control", "auc.treatment", "abc")] <-
        c(sl$control$value, sl$treatment$value, sl$value)
    }
  }

  ##--------------code for batch level mR --------------------------------------

  slot(object, "sensitivity") <- sen
  return(object)
}



#' compute response
#'
#' \code{response} computes response of a PDX model or batch
#'
#' @param object Xeva object
#' @param res.measure response measure
#' @param model.id model id for which response to be computed
#' @param batch batch id or experiment design for which response to be computed
#' @param treatment.only Default \code{FALSE}. If TRUE give data only for non-zero dose periode (if dose data avalible)
#' @param min.time default \strong{10} days. Used for \emph{mRECIST} computation
#' @param max.time maximum time for data
#' @param vol.normal default \code{TRUE} will use
#' @param impute.value default \code{FALSE}. If TRUE will impute the values
#' @param concurrent.time default \code{FALSE}. If TRUE will cut the batch data such that control and treatment will end at same time point
#' @param verbose default \code{TRUE} will print infromation
#'
#' @return  returns model or batch response object
#'
#' @examples
#' data(brca)
#' response(brca, model.id="X.1004.BG98", res.measure="mRECIST")
#'
#' response(brca, batch="X-6047.paclitaxel", res.measure="angle")
#'
#' ed <- list(batch.name="myBatch", treatment=c("X.6047.LJ16","X.6047.LJ16.trab"),
#'              control=c("X.6047.uned"))
#' response(brca, batch=ed, res.measure="angle")
#'
#' @export
response <- function(object, model.id=NULL,
                     batch=NULL,
                     res.measure=c("angle", "mRECIST", "AUC", "angle", "abc"),
                     treatment.only=TRUE, max.time=NULL, impute.value=TRUE,
                     min.time=10, concurrent.time =TRUE, vol.normal=F,
                     verbose=TRUE)
{
  if(is.null(model.id) & is.null(batch)) #Name) & is.null(expDig))
  { stop("'model.id', 'batch' all NULL") }

  model.measure <- c("mRECIST", "best.response", "best.response.time",
                     "best.average.response", "best.average.response.time",
                     "slope", "AUC")

  batch.measure <- c("angle")

  ##------------- for model ----------------------------------------------------
  if(!is.null(model.id))
  {
    dl <- getExperiment(object, model.id=model.id[1], treatment.only=treatment.only,
                        max.time=max.time, vol.normal=vol.normal,
                        impute.value=impute.value)

    ###--------compute mRECIST -------------------------------------------------
    if(any(c("mRECIST", "best.response", "best.average.response") %in% res.measure))
    {
      if(verbose==TRUE) {cat(sprintf("computing mRECIST for %s\n", model.id))}
      mr <- mRECIST(dl$time, dl$volume, min.time=min.time, return.detail=TRUE)
      return(mr)
    }

    ###--------compute slope -----------------------------------------------------
    if(res.measure=="slope")
    {
      if(verbose==TRUE) {cat(sprintf("computing slope for %s\n", model.id))}
      return(slope(dl$time, dl$volume, degree=TRUE))
    }

    ###--------compute AUC -------------------------------------------------------
    if(res.measure=="AUC")
    {
      if(verbose==TRUE) {cat(sprintf("computing AUC for %s\n", model.id))}
      return( AUC(dl$time, dl$volume))
    }

  }

  ##-----------------for batch -------------------------------------------------
  if(is.null(model.id))
  {
    dl <- getExperiment(object, batch=batch,
                        treatment.only=treatment.only, max.time=max.time,
                        vol.normal=vol.normal, impute.value=impute.value,
                        concurrent.time=concurrent.time)

    cInd <- dl$batch$exp.type == "control"
    tInd <- dl$batch$exp.type == "treatment"

    contr.time <- contr.volume <- treat.time <- treat.volume <- NULL
    if(sum(cInd)>1)
    { contr.time <- dl$batch$time[cInd]; contr.volume <- dl$batch$mean[cInd] }

    if(sum(tInd)>1)
    { treat.time <- dl$batch$time[tInd]; treat.volume <- dl$batch$mean[tInd]}

    if(verbose==TRUE){
      if(is.character(batch))
        {bName <- batch} else {bName <- batch$batch.name}
      cat(sprintf("computing %s for batch %s\n",res.measure, bName))

      }
    ###--------compute angle for batch -----------------------------------------
    if(res.measure =="angle")
    {
      rtx <- angle(contr.time, contr.volume, treat.time,treat.volume, degree=TRUE)
      return(rtx)
    }

    ###--------compute abc for batch ---------------------------------------------
    if(res.measure=="abc")
    {
      rtx <- ABC(contr.time, contr.volume, treat.time, treat.volume)
      return(rtx)
    }
  }

}