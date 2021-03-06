##---- functions to access experiment slot --------

drugMatchFun <- function(drug, objPDX, exact.match)
{
  objDrugNames = toupper(objPDX$drug$names)
  if(exact.match == TRUE &
     length(intersect(drug, objDrugNames))== length(objDrugNames) &
     length(intersect(drug, objDrugNames))== length(drug) )
  { return(TRUE) }

  if(exact.match == FALSE & length(intersect(drug, objDrugNames))>0 )
  { return(TRUE) }

  return(FALSE)
}

tumorTypeMatchFun<- function(tissue, objPDX)
{

  if (toupper(tissue) == toupper(objPDX$tissue))
  {return(TRUE)}

  return(FALSE)
}

getModels <- function(expSlot, drug=NULL, drug.exact.match=TRUE, tissue=NULL)
{
  objIndx = list()
  if(!(is.null(drug)))
  {
    drug = c(toupper(drug))
    objIndx[["Drug"]] = sapply(expSlot, drugMatchFun, drug=drug, exact.match=drug.exact.match)
  }

  if(!(is.null(tissue)))
  {
    objIndx[["tissue"]] = sapply(expSlot, tumorTypeMatchFun, tissue=tissue)
  }

  rtIndx = apply( do.call(cbind.data.frame, objIndx), 1, all )
  #rtName = sapply(expSlot, "[[", "model.id")[rtIndx]
  rtName = names(expSlot)[rtIndx]

  #return(expSlot[rtIndx])
  return(rtName)
}


getTreatmentControlForModel <- function(model.idx, model)
{
  batchID = model[model$model.id ==model.idx, "batch"]
  return(model[model$batch==batchID, c("model.id", "batch", "exp.type")])
}


getTreatmentControlX <- function(expSlot, objNames, model)
{
  drgNames  = unique(sapply(expSlot[objNames], "[[", c("drug", "join.name")))
  tretBatch = unique(model[model$drug.join.name%in% drgNames,  "batch"])

  rtx=list()
  for(drgI in drgNames)
  {
    for(batI in tretBatch)
    {
      Lx = list(drug.join.name = drgI,
                batch = batI)
      Lx$treatment = unique(model[model$drug.join.name == drgI &
                        model$batch == batI &
                        model$exp.type == "treatment", "model.id"] )

      Lx$control = unique(model[model$batch == batI & model$exp.type == "control", "model.id"] )

      namx = sprintf("%s.%s", drgI, batI)
      rtx[[namx]]= Lx
    }
  }


  rdf = data.frame()
  for(model.idx in objNames)
  {
    tc = getTreatmentControlForModel(model.idx, model)
    tc$drug.join.name = sapply(expSlot[tc$model.id], "[[", c("drug", "join.name"))
    rdf = rbind(rdf, tc)
  }

  rdf = unique(rdf)
  #tretID = rdf[rdf$exp.type=="treatment", "model.id"]
  drgeID = unique(rdf[rdf$exp.type=="treatment", "drug.join.name"])
  rtx = list()
  for(drI in drgeID)
  {
    rdf[rdf$drug.join.name==drI, ]
  }


  return(rtx)
}


getExpDesign <- function(objNames, expDesign)
{
  expDesIndx = sapply(expDesign, function(x){
                      if( length(intersect(objNames, c(x$treatment,x$control) ))>0)
                      {return(TRUE)}
                      return(FALSE) })
  expDesName = names(expDesign)[expDesIndx]
  return(expDesign[expDesName])
}










