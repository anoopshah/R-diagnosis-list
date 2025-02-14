#' Sample extended map table from SNOMED CT dictionary
#'
#' A sample of the SNOMED CT extended map table, containing maps to ICD-10 and OPCS4. 
#' 
#' @name SNOMED_EXTENDEDMAP
#' @aliases EXTENDEDMAP
#' @importFrom utils data
#' @docType data
#' @usage data(EXTENDEDMAP)
#' @format An object of class \code{"data.table"}
#' @keywords datasets
#'
#' @details
#' \describe{
#'   \item{moduleId}{ integer64: core metadata concept: 449080006 = SNOMED CT to ICD-10 rule-based mapping module, 999000031000000106 = SNOMED CT United Kingdom Edition reference set module}
#'   \item{refsetId}{ integer64: foundation metadata concept: 447562003 = ICD-10 complex map reference set, 1126441000000105 = Office of Population Censuses and Surveys Classification of Interventions and Procedures Version 4.9 complex map reference set, 999002271000000101 = International Classification of Diseases, Tenth Revision, Fifth Edition, five character code United Kingdom complex map reference set}
#'   \item{referencedComponentId}{ integer64: SNOMED CT conceptId of the concept mapped}
#'   \item{mapGroup}{ integer: mapping group}
#'   \item{mapPriority}{ integer: priority of alternative maps (1 = highest)}
#'   \item{mapRule}{ character: advice on mapping rule}
#'   \item{mapAdvice}{ character: mapping advice}
#'   \item{mapTarget}{ character: target ICD-10 or OPCS4 code. The optional period between the third and fourth character has been removed for consistency.}
#'   \item{mapCategoryId}{ integer64: foundation metadata concept describing the quality of the map}
#'   \item{effectiveTime}{ IDate: when the concept became active}
#'   \item{active}{ logical: whether this concept is currently active}
#' }
#' 
#' @family sampleSNOMED
#' @examples
#' # Load the dataset and show its properties
#' data('EXTENDEDMAP')
#' str(EXTENDEDMAP)
#'
#' # This EXTENDEDMAP table is part of the sample SNOMED CT dictionary
#' # Hence this should show the same properties as above
#' str(sampleSNOMED()$EXTENDEDMAP)
"EXTENDEDMAP"
