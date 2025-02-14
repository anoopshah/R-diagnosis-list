#' Obtain related concepts for a set of SNOMED CT concepts
#'
#' Returns concepts with a particular relation to a supplied set of
#' SNOMED CT concepts
#'
#' @param conceptIds character or integer64 vector
#' @param typeId concept ID of relationship type.
#'   Defaults to 116680003 = Is a
#' @param tables vector of names of relationship table(s) to use;
#'   by default use both RELATIONSHIP and STATEDRELATIONSHIP
#' @param reverse whether to reverse the relationship
#' @param recursive whether to re-apply the function on the outputs
#' @param active_only whether to limit the output to active concepts only
#' @param SNOMED environment containing a SNOMED dictionary
#' @return a data.table with the following columns: id, conceptId, type
#'   (only if include_synonyms = TRUE), term,
#'   active (only if active_only = FALSE)
#' @export
#' @examples
#' # Load sample SNOMED CT dictionary
#' SNOMED <- sampleSNOMED()
#'
#' # Example: anatomical site of a finding
#' findingSite <- function(x){
#'   relatedConcepts(as.SNOMEDconcept(x),
#'     typeId = as.SNOMEDconcept('Finding site'))
#' }
#' 
#' description(findingSite('Heart failure'))
#' # Heart structure (body structure)
relatedConcepts <- function(conceptIds,
	typeId = bit64::as.integer64('116680003'),
	tables = c('RELATIONSHIP', 'STATEDRELATIONSHIP'),
	reverse = FALSE, recursive = FALSE, active_only = TRUE,
	SNOMED = getSNOMED()){
	# Returns the original concepts and the linked concepts

	active <- sourceId <- destinationId <- conceptId <- NULL

	conceptIds <- unique(as.SNOMEDconcept(conceptIds, SNOMED = SNOMED))
	typeId <- as.SNOMEDconcept(typeId, SNOMED = SNOMED)
	
	# If no concepts supplied, return an empty vector
	if (length(conceptIds) == 0){
		return(conceptIds)
	}

	if (active_only){
		if (reverse){
			TOLINK <- data.table(destinationId = conceptIds,
				typeId = typeId, active = TRUE)
		} else {
			TOLINK <- data.table(sourceId = conceptIds,
				typeId = typeId, active = TRUE)
		}
	} else {
		if (reverse){
			TOLINK <- data.table(destinationId = conceptIds,
				typeId = typeId)
		} else {
			TOLINK <- data.table(sourceId = conceptIds,
				typeId = typeId)
		}	
	}

	# Retrieve concepts with the relevant relationship
	getRelationship <- function(tablename, active_only){
		TABLE <- get(tablename, envir = SNOMED)
		if (active_only){
			if (reverse){
				return(TABLE[TOLINK, on = c('destinationId', 'typeId',
					'active')]$sourceId)
			} else {
				return(TABLE[TOLINK, on = c('sourceId', 'typeId',
					'active')]$destinationId)
			}
		} else {
			if (reverse){
				return(TABLE[TOLINK,
					on = c('destinationId', 'typeId')]$sourceId)
			} else {
				return(TABLE[TOLINK,
					on = c('sourceId', 'typeId')]$destinationId)
			}
		}
	}

	# Add relationships from each table
	out <- unique(as.SNOMEDconcept(getRelationship(tables[1],
		active_only), SNOMED = SNOMED))
	if (length(tables) > 1){
		for (table in tables[-1]){
			out <- union(out, getRelationship(table, active_only))
		}
	}
	# Remove NA values
	out <- out[!is.na(out)]

	# Recursion if appropriate
	if (recursive == TRUE){
		# Include original concepts for recursion
		out <- union(conceptIds, out)
		if (length(conceptIds) < length(out)){
			# Recurse
			return(relatedConcepts(conceptIds = out,
				typeId = typeId, SNOMED = SNOMED, tables = tables,
				reverse = reverse, recursive = TRUE,
				active_only = active_only))
		} else {
			return(out)
		}
	} else {
		return(out)
	}
}

#' Ancestors and descendants of SNOMED CT concepts
#'
#' Returns concepts with 'Is a' or inverse 'Is a'
#' relationship with a set of target concepts. 
#' Ancestors include parents and all higher relations.
#' Descendants include children and all lower relations.
#'
#' @param conceptIds character or integer64 vector of SNOMED concept IDs
#' @param SNOMED environment containing a SNOMED dictionary
#' @param include_self whether to include the original concept(s) in the
#'   output, default = FALSE
#' @param TRANSITIVE transitive closure table for ancestors and
#'   descendants, containing is-a relationships. This table can be 
#'   created by createTransitive to speed up the ancestor / descendant
#'   functions. If a TRANSITIVE table is provided, the SNOMED environment
#'   is not used and relatedConcepts is not called. TRANSITIVE should be
#'   a data.table with columns ancestorId and descendantId.
#' @param ... other arguments to pass to relatedConcepts
#' @return a bit64 vector of SNOMED CT concepts
#' @export
#' @seealso [createTransitive()] for creation of TRANSITIVE table, and
#'   [relatedConcepts()] for the underlying function to extract
#'   SNOMED CT relationships. 
#' @examples
#' SNOMED <- sampleSNOMED()
#'
#' parents('Heart failure')
#' children('Heart failure')
#' ancestors('Heart failure')
#' descendants('Heart failure')
parents <- function(conceptIds, include_self = FALSE, 
	SNOMED = getSNOMED(), TRANSITIVE = NULL, ...){
	conceptIds <- unique(as.SNOMEDconcept(conceptIds, SNOMED = SNOMED))
	parentIds <- relatedConcepts(conceptIds = conceptIds,
		typeId = bit64::as.integer64('116680003'),
		reverse = FALSE, recursive = FALSE, SNOMED = SNOMED, ...)
	
	if (include_self){
		return(sort(union(parentIds, conceptIds)))
	} else {
		# Exclude originals
		if (length(parentIds) > 0){
			return(as.SNOMEDconcept(sort(parentIds[
				!(parentIds %in% conceptIds)]), SNOMED = SNOMED))
		} else {
			return(parentIds) # zero length
		}
	}
}

#' @rdname parents
#' @export
ancestors <- function(conceptIds, include_self = FALSE, 
	SNOMED = getSNOMED(), TRANSITIVE = NULL, ...){
	conceptIds <- unique(as.SNOMEDconcept(conceptIds, SNOMED = SNOMED))
	if (is.null(TRANSITIVE)){
		ancestorIds <- relatedConcepts(conceptIds = conceptIds,
			typeId = bit64::as.integer64('116680003'),
			reverse = FALSE, recursive = TRUE, SNOMED = SNOMED, ...)
	} else {
		ancestorIds <- as.SNOMEDconcept(TRANSITIVE[
			data.table(descendantId = conceptIds),
			on = 'descendantId']$ancestorId, SNOMED = SNOMED)
	}

	if (include_self){
		return(sort(union(ancestorIds, conceptIds)))
	} else {
		# Exclude originals
		if (length(ancestorIds) > 0){
			return(as.SNOMEDconcept(sort(ancestorIds[
				!(ancestorIds %in% conceptIds)]), SNOMED = SNOMED))
		} else {
			return(ancestorIds) # zero length
		}
	}
}

#' @rdname parents
#' @export
children <- function(conceptIds, include_self = FALSE, 
	SNOMED = getSNOMED(), TRANSITIVE = NULL, ...){
	conceptIds <- unique(as.SNOMEDconcept(conceptIds, SNOMED = SNOMED))
	childIds <- relatedConcepts(conceptIds = conceptIds,
		typeId = bit64::as.integer64('116680003'),
		reverse = TRUE, recursive = FALSE, SNOMED = SNOMED, ...)

	if (include_self){
		return(sort(union(childIds, conceptIds)))
	} else {
		# Exclude originals
		if (length(childIds) > 0){
			return(as.SNOMEDconcept(sort(childIds[
				!(childIds %in% conceptIds)]), SNOMED = SNOMED))
		} else {
			return(childIds) # zero length
		}
	}
}

#' @rdname parents
#' @export
descendants <- function(conceptIds, include_self = FALSE, 
	SNOMED = getSNOMED(), TRANSITIVE = NULL, ...){
	conceptIds <- unique(as.SNOMEDconcept(conceptIds, SNOMED = SNOMED))
	if (is.null(TRANSITIVE)){
		descendantIds <- relatedConcepts(conceptIds = conceptIds,
			typeId = bit64::as.integer64('116680003'),
			reverse = TRUE, recursive = TRUE, SNOMED = SNOMED, ...)
	} else {
		descendantIds <- as.SNOMEDconcept(TRANSITIVE[
			data.table(ancestorId = conceptIds),
			on = 'ancestorId']$descendantId, SNOMED = SNOMED)
	}

	if (include_self){
		return(sort(union(descendantIds, conceptIds)))
	} else {
		# Exclude originals
		if (length(descendantIds) > 0){
			return(as.SNOMEDconcept(sort(descendantIds[
				!(descendantIds %in% conceptIds)]), SNOMED = SNOMED))
		} else {
			return(descendantIds) # zero length
		}
	}
}

#' Create a transitive closure table for is-a relationships for
#' faster ancestor / descendant lookups
#'
#' Returns a data.table containing ancestor / descendant relationships
#' which can be used in ancestors and descendants functions
#'
#' @param conceptIds character or integer64 vector of SNOMED concept IDs
#'   for the subset of concepts to include in the transitive table.
#' @param SNOMED environment containing a SNOMED dictionary
#' @param tables vector of names of relationship table(s) to use;
#'   by default use both RELATIONSHIP and STATEDRELATIONSHIP
#' @seealso [ancestors()] and [descendants()]
#' @export
#' @examples
#' SNOMED <- sampleSNOMED()
#'
#' TRANSITIVE <- createTransitive('Heart failure')
createTransitive <- function(conceptIds, SNOMED = getSNOMED(),
	tables = c('RELATIONSHIP', 'STATEDRELATIONSHIP')){
		
	# Define symbols for R CMD check
	childId <- parentId <- sourceId <- destinationId <- typeId <- NULL
	descendantId <- ancestorId <- NULL
	
	conceptIds <- as.SNOMEDconcept(conceptIds, SNOMED = SNOMED)
	WORKING <- rbindlist(lapply(tables, function(x){
		TEMP <- get(x, envir = SNOMED)
		if (nrow(TEMP) == 0){
			data.table(childId = bit64::as.integer64(0),
				parentId = bit64::as.integer64(0))
		} else {
			TEMP[(sourceId %in% conceptIds |
				destinationId %in% conceptIds) &
				typeId == bit64::as.integer64('116680003'),
				list(childId = sourceId, parentId = destinationId)]
		}
	}))
	WORKING <- WORKING[!duplicated(WORKING)]
	new_nrows <- nrow(WORKING)
	old_nrows <- 0
	while(new_nrows > old_nrows){
		WORKING <- rbind(WORKING, merge(
			WORKING[, list(childId, selfId = parentId)],
			WORKING[, list(selfId = childId, parentId)], by = 'selfId',
			allow.cartesian = TRUE)[, list(childId, parentId)])
		WORKING <- WORKING[!duplicated(WORKING)]
		old_nrows <- new_nrows
		new_nrows <- nrow(WORKING)
	}
	OUT <- WORKING[childId %in% conceptIds & parentId %in% conceptIds,
		list(ancestorId = parentId, descendantId = childId)]
	setkey(OUT, descendantId)
	setindex(OUT, ancestorId)
	OUT
}

#' Whether SNOMED CT concepts have particular attributes
#'
#' For each concept in the first list, whether it has the attribute
#' in the second list. Returns a vector of Booleans.
#'
#' @param sourceIds character or integer64 vector of SNOMED concept IDs
#'   for children, recycled if necessary
#' @param destinationIds character or integer64 vector of SNOMED concept
#'   IDs for parents, recycled if necessary
#' @param typeIds character or integer64 vector of SNOMED concept IDs
#'   for renationship types, recycled if necessary.
#'   Defaults to 116680003 = 'Is a' (child/parent)
#' @param SNOMED environment containing a SNOMED dictionary
#' @param active_only whether only active relationships
#'   should be considered, default TRUE
#' @param tables character vector of relationship tables to use
#' @return a vector of Booleans stating whether the attribute exists
#' @export
#' @examples
#' data.table::setDTthreads(threads = 1) # for CRAN testing
#'
#' SNOMED <- sampleSNOMED()
#'
#' hasAttributes(c('Heart failure', 'Acute heart failure'),
#'   c('Heart structure', 'Heart failure'),
#'   c('Finding site', 'Is a'))
hasAttributes <- function(sourceIds, destinationIds,
	typeIds = bit64::as.integer64('116680003'),
	SNOMED = getSNOMED(), 
	tables = c('RELATIONSHIP', 'STATEDRELATIONSHIP'),
	active_only = TRUE){
	IN <- data.table(
		sourceId = as.SNOMEDconcept(sourceIds, SNOMED = SNOMED),
		destinationId = as.SNOMEDconcept(destinationIds, SNOMED = SNOMED),
		typeId = as.SNOMEDconcept(typeIds, SNOMED = SNOMED))
	TOMATCH <- IN[!duplicated(IN)]
	
	sourceId <- destinationId <- typeId <- active <- NULL
	
	# add matches and combine Boolean
	addRelationship <- function(tablename, out){
		TABLE <- as.data.table(get(tablename, envir = SNOMED))
		if (active_only & inactiveIncluded(SNOMED)){
			TEMP <- merge(TOMATCH, TABLE[active == TRUE,
				list(sourceId, destinationId, typeId, found = TRUE)],
				by = c('sourceId', 'destinationId', 'typeId'))
		} else {
			TEMP <- merge(TOMATCH, TABLE[,
				list(sourceId, destinationId, typeId, found = TRUE)],
				by = c('sourceId', 'destinationId', 'typeId'))
		}
		TEMP <- TEMP[!duplicated(TEMP)]
		out | !is.na(TEMP[IN, on = c('sourceId', 'destinationId',
			'typeId')]$found)
	}
	
	# Blank output logical vector
	out <- logical(nrow(TOMATCH))
	# Add relationships from each table
	for (table in tables){
		out <- addRelationship(table, out)
	}
	return(out)
}

#' Retrieve all attributes of a set of SNOMED CT concepts
#'
#' Returns the portion of the SNOMED CT relationship tables containing
#' relationships where the given concepts are either the source or the 
#' destination.
#'
#' @param conceptIds character or integer64 vector of SNOMED concept IDs
#' @param SNOMED environment containing a SNOMED dictionary
#' @param tables character vector of relationship tables to use
#' @param active_only whether to return only active attributes
#' @return a data.table with the following columns: 
#'   sourceId (concept ID of source for relationship),
#'   destinationId (concept ID of source for relationship),
#'   typeId (concept ID of relationship type),
#'   typeName (description of relationship type)
#'
#' @export
#' @examples
#' SNOMED <- sampleSNOMED()
#'
#' attrConcept(as.SNOMEDconcept('Heart failure'))
attrConcept <- function(conceptIds,
	SNOMED = getSNOMED(), 
	tables = c('RELATIONSHIP', 'STATEDRELATIONSHIP'),
	active_only = TRUE){
	# Retrieves a table of attributes for a given set of concepts
	# add matches and combine Boolean
	sourceId <- destinationId <- typeId <- relationshipGroup <- NULL
	sourceDesc <- destinationDesc <- typeDesc <- active <- NULL

	MATCHSOURCE <- data.table(sourceId =
		as.SNOMEDconcept(conceptIds, SNOMED = SNOMED))
	MATCHDEST <- data.table(destinationId =
		as.SNOMEDconcept(conceptIds, SNOMED = SNOMED))
	OUT <- rbind(rbindlist(lapply(tables, function(table){
			get(table, envir = SNOMED)[MATCHSOURCE, on = 'sourceId',
			list(sourceId, destinationId, typeId, relationshipGroup, active)]
		}), use.names = TRUE, fill = TRUE),
		rbindlist(lapply(tables, function(table){
			get(table, envir = SNOMED)[MATCHDEST, on = 'destinationId',
			list(sourceId, destinationId, typeId, relationshipGroup, active)]
		}), use.names = TRUE, fill = TRUE)
	)
	if (active_only == TRUE & inactiveIncluded(SNOMED)){
		OUT <- OUT[active == TRUE]
	}
	OUT[, sourceDesc := description(sourceId, SNOMED = SNOMED)$term]
	OUT[, destinationDesc := description(destinationId,
		SNOMED = SNOMED)$term]
	OUT[, typeDesc := description(typeId, SNOMED = SNOMED)$term]
	return(OUT[])
}

#' Retrieves semantic types using the text 'tag' in the description
#'
#' Uses the fully specified name in the DESCRIPTION table. If there are
#' multiple fully specified names, the name with the most recent
#' effectiveTime will be used.
#'
#' @param conceptIds character or integer64 vector of SNOMED concept IDs
#' @param SNOMED environment containing a SNOMED dictionary
#' @return a character vector of semantic tags corresponding to the conceptIDs 
#'   
#' @export
#' @examples
#' SNOMED <- sampleSNOMED()
#'
#' semanticType(as.SNOMEDconcept(c('Heart failure', 'Is a')))
semanticType <- function(conceptIds, SNOMED = getSNOMED()){
	
	# Declare symbols to avoid R check error
	tag <- term <- conceptId <- typeId <- active <- NULL
	effectiveTime <- NULL
	
	conceptIds <- as.SNOMEDconcept(conceptIds, SNOMED = SNOMED)
	DESC <- SNOMED$DESCRIPTION[conceptId %in% conceptIds & typeId %in%
		bit64::as.integer64('900000000000003001') & active %in% TRUE,
		list(conceptId, effectiveTime, term)][
		order(conceptId, -effectiveTime)][
		, list(term = term[1]), by = conceptId]
	DESC <- DESC[data.table(conceptId = conceptIds), on = 'conceptId']
	DESC[, tag := ifelse(term %like% '^.*\\(([[:alnum:]\\/\\+ ]+)\\)$',
		sub('^.*\\(([[:alnum:]\\/\\+ ]+)\\)$', '\\1', term), '')]
	return(DESC$tag)
}

#' Retrieves closest single ancestor within a given set of SNOMED CT
#' concepts
#'
#' Returns a vector of SNOMED CT concept IDs for an ancestor of each
#' concept that is within a second list. If multiple ancestors are
#' included in the second list, the concept is not simplified (i.e.
#' the original concept ID is returned).
#' This functionality can be used to translate concepts into simpler
#' forms for display, e.g. 'Heart failure' instead of 'Heart failure
#' with reduced ejection fraction'.
#'
#' This function is intended for use with active SNOMED CT concepts only.
#'
#' @param conceptIds character or integer64 vector of SNOMED concept IDs
#'   for concepts for which an ancestor is sought
#' @param ancestorIds character or integer64 vector of SNOMED concept IDs
#'   for possible ancestors
#' @param SNOMED environment containing a SNOMED dictionary
#' @param tables character vector of relationship tables to use
#' @return a data.table with the following columns:
#'   originalId (integer64) = original conceptId,
#'   ancestorId (integer64) = closest single ancestor, or original
#'   concept ID if no ancestor is included among ancestorIds
#'   
#' @export
#' @examples
#' SNOMED <- sampleSNOMED()
#'
#' original_terms <- c('Systolic heart failure', 'Is a',
#'   'Heart failure with reduced ejection fraction',
#'   'Acute kidney injury due to circulatory failure (disorder)')
#' # Note in this example 'Is a' has no parents in ancestors,
#' # and acute kidney failure has two parents in ancestors
#' # so neither of the parents will be chosen.
#' # Also test out inclusion of duplicate concepts.
#'
#' ancestors <- simplify(c(as.SNOMEDconcept(original_terms),
#'   as.SNOMEDconcept(original_terms)[3:4]),
#'   as.SNOMEDconcept(c('Heart failure', 'Acute heart failure',
#'   'Cardiorenal syndrome (disorder)')))
#' print(cbind(original_terms, description(ancestors$ancestorId)$term))
simplify <- function(conceptIds, ancestorIds,
	SNOMED = getSNOMED(), 
	tables = c('RELATIONSHIP', 'STATEDRELATIONSHIP')){
	found <- keep_orig <- anymatch <- originalId <- NULL
	ancestorId <- conceptId <- NULL

	DATA <- data.table(conceptId = conceptIds,
		originalId = conceptIds, found = FALSE, anymatch = FALSE,
		keep_orig = FALSE, order = 1:length(conceptIds))
	# order = identifier for the original concept (in case of duplicates)
	# original = original concept
	# conceptId = candidate closest single ancestor
	# found = whether this row is a match to closest ancestor
	# anymatch = whether any match is found for this concept
	# keep_orig = whether to keep original because 0 or > 1 matches

	recursionlimit <- 10
	# Loop while any of the concepts are unmatched and recursion
	# limit is not reached
	while(any(DATA$anymatch == FALSE) & recursionlimit > 0){
		# Check for matches
		DATA[conceptId %in% ancestorIds, found := TRUE]
		# Keep original (ignore match) if more than one match
		DATA[, keep_orig := keep_orig | sum(found) > 1, by = order]
		DATA[, anymatch := any(found), by = order]
		# anymatch means at least one match has been found,
		# or a decision has been made to keep the original term
		DATA[keep_orig == TRUE, anymatch := TRUE]
		
		# Expand ancestors for terms without a match
		if (any(DATA$anymatch == FALSE)){
			EXPANDED <- DATA[anymatch == FALSE][,
				list(conceptId = parents(conceptId, SNOMED = SNOMED,
				tables = tables)),
				by = list(originalId, found, anymatch, keep_orig, order)]
			DATA <- rbind(DATA, EXPANDED)
		}
		recursionlimit <- recursionlimit - 1
	}
	
	# Keep original if no matches
	DATA[, keep_orig := keep_orig | (anymatch == FALSE), by = order]
	# If keeping the original concept, keep only the first row
	DATA[keep_orig == TRUE, found := c(TRUE, rep(FALSE, .N - 1)), by = order]
	DATA <- DATA[found == TRUE]
	setkey(DATA, order)
	# Now there should be one row per order
	stopifnot(DATA$order == seq_along(conceptIds))
	data.table::setnames(DATA, 'conceptId', 'ancestorId')
	DATA[keep_orig == TRUE, ancestorId := originalId]
	DATA[, order := NULL]
	DATA[, keep_orig := NULL]
	DATA[, found := NULL]
	DATA[, anymatch := NULL]
	return(DATA)
}


 
