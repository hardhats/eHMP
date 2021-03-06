'use strict';

//--------------------------------------------------------------------------------
// This is a record enrichment transformer for image data.
//
// @Author:  Les Westberg
//--------------------------------------------------------------------------------

var xformerProcedureRecEnrichment = require(global.VX_HANDLERS + 'record-enrichment-request/record-enrichment-procedure-xformer');

//--------------------------------------------------------------------------------
// This method transfroms and enriches the image record.
//
// log: The logger to send log messages to.
// config: The configuration information
// environment: The environment handles and context.
// job: The record enrichment job to be processed.
// callback: This is the handler to call when the enrichment transformation is done.
//                  function(error, record)  where:
//                       Error is the error that occurred.
//                       record is the transformed and enriched record.
//--------------------------------------------------------------------------------
function transformAndEnrichRecord(log, config, environment, job, callback) {
	log.debug('record-enrichment-image-xformer.transformAndEnrichRecord: Entered method.  job: %j', job);

	// Make sure we have something to work with.
	//------------------------------------------
	if ((!job) || (!job.record)) {
		log.warn('record-enrichment-image-xformer.transformAndEnrichRecord: Job either did not exist or did not contain a record.  job: %j', job);
		return setTimeout(callback, 0, null, null);
	}

	var record = job.record;

	// Note that the structure of appointment data is identical to the structure of
	// procedure data. So we just need to do call the procedure transformation
	// to complete this one.
	//--------------------------------------------------------------------------
	xformerProcedureRecEnrichment.transformAndEnrichRecordAPI(record);
	log.debug('record-enrichment-image-xformer.transformAndEnrichRecord: transformed record being returned.  record: %j', record);
	return callback(null, record);
}

module.exports = transformAndEnrichRecord;
