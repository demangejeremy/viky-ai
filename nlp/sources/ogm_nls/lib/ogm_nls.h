/*
 *  Internal header for Natural Language Server library
 *  Copyright (c) 2017 Pertimm by Patrick Constant
 *  Dev: August 2017
 *  Version 1.0
 */
#include <lognls.h>
#include <lognlp.h>

#include <logaddr.h>
#include <loguci.h>
#include <logpath.h>
#include <logthr.h>
#include <logheap.h>
#include <loggen.h>
#include <glib.h>

#include <jansson.h>

#include <uriparser/Uri.h>

#include <string.h>

typedef struct og_listening_thread og_listening_thread;

#define DOgNlsPortNumber  9345

struct timeout_conf_context
{
  char *timeout_name; /** name of the timeout : answer_timeout, socket_read_timeout...*/
  int old_timeout; /** timeout from previous conf */
  int default_timeout; /** default timeout value */
};

struct og_nls_env
{
  char listenning_address[DPcPathSize];
  int listenning_port;
  og_bool wait_to_be_ready;
};

struct og_nls_conf
{

  struct og_nls_env env[1];

  int max_listening_threads;
  int max_parallel_threads;
  char data_directory[DPcPathSize];
  int permanent_threads;

  int max_request_size;

  /** Global timeout determining socket_read_timeout and request_processing_timeout*/
  int answer_timeout;

  /** backlog timeout. If only answer_timeout is specified, backlog_timeout is 10 % of answer_timeout*/
  int backlog_timeout;

  /** socket timeout. If only answer_timeout is specified, socket_read_timeout is 10 % of answer_timeout*/
  int socket_read_timeout;

  /** Timeout for the request. If only answer_timeout is specified, request_processing_timeout is 80 % of answer_timeout*/
  int request_processing_timeout;

  /** backlog timeout specified only for indexing requests. If not specified, it has the same value as backlog_timeout*/
  int backlog_indexing_timeout;
  int backlog_max_pending_requests;

};

struct og_nls_options
{
  /** Current request processing timeout */
  int request_processing_timeout;
};

struct og_nls_request
{

  /* json_array : containing all parameters keys only to keep keys in memory */
  json_t *parameters_keys;

  /* json_object : containing all parameters : key -> value */
  json_t *parameters;

  /* By default it is an empty json_object */
  json_t *body;

  struct og_ucisr_output *raw;

};

struct og_nls_response
{
  int http_status;
  og_string http_message;

  json_t *default_body;
  json_t *body;
  json_t *custom_errors;
};

enum lt_running_state
{
  lt_running_state_waiting = 0,   //
  lt_running_state_running = 1,   //
  lt_running_state_cleanning = 2,   //
};

/** data structure for a listening thread **/
struct og_listening_thread
{
  struct og_ctrl_nls *ctrl_nls;
  int ID;

  /** Error handler */
  void *herr;

  /** Message handler */
  void *hmsg;

  ogmutex_t *hmutex;
  struct og_loginfo loginfo[1];

  enum lt_running_state state;
  int request_running_start;
  int request_running_time;

  ogthread_t IT;
  unsigned hsocket_in;
  int connection_closed;
  struct sockaddr_in socket_in;

  struct og_ucisr_output output[1];
  void *hucis;

  /** for permanent lt threads **/
  ogsem_t hsem[1];
  og_bool must_stop;
  og_bool is_stopped;

  ogint64_t t0, t1, t2, t3, ot3;

  pthread_t current_thread;
  struct og_nls_options options[1];

  /** Heap of char */
  og_heap h_json_answer;

  /** Nlp local thread handler*/
  og_nlp_th hnlp_th;

  /** Endpoint in/out structure are kept here for memory release after request is finished */
  struct og_nls_request request[1];
  struct og_nls_response response[1];

};

/** nlsmt.c **/
#define DOgNlsClockTick        10

/** data structure for the maintenance thread **/
struct og_maintenance_thread
{
  void *herr;
  void *hmsg;
  ogmutex_t *hmutex;

  og_bool mt_should_stop;
  og_bool mt_is_stopped;

  struct og_ctrl_nls *ctrl_nls;

  ogthread_t IT;
};

struct og_ctrl_nls
{
  void *herr, *hmsg;
  ogmutex_t *hmutex;
  struct og_loginfo loginfo[1];
  char WorkingDirectory[DPcPathSize];
  char configuration_file[DPcPathSize];
  char pidfile[DPcPathSize];
  char import_directory[DPcPathSize];

  int icwd;
  unsigned char cwd[DPcPathSize];
  struct og_nls_conf conf[1];

  struct og_ucisr_output output[1];
  struct og_ucisw_input winput[1];
  struct og_ucisr_input input[1];

  char sremote_addr[DPcPathSize];
  int must_stop;

  void *haddr;
  void *hucis;
  void *hucic;

  og_bool nls_ready;

  struct og_listening_thread *Lt;
  int LtNumber;

  ogsem_t hsem_run3[1];
  /** Mutex to choose current lt */
  ogmutex_t hmutex_run_lt[1];

  struct og_maintenance_thread mt[1];

  /** Nlp common memmory : should not be use except in init phase */
  og_nlp hnlp;

  /** Nlp local thread memory : should not be use except in init phase */
  og_nlp_th hnlpi_main;

};

#define maxArrayLevel 10

/** inls.c **/
og_status OgNlsWritePidFile(og_nls ctrl_nls);
void OgNlsMemLogPeakUsage(og_nls ctrl_nls, og_string context);

/** nlsrun.c **/
int NlsRunSendErrorStatus(void *ptr, struct og_socket_info *info, int error_status, og_string message);
int NlsWaitForListeningThreads(char *label, struct og_ctrl_nls *ctrl_nls);

/** nlsltp.c Permanent threads **/
int OgPermanentLtThread(void *ptr);
int NlsInitPermanentLtThreads(struct og_ctrl_nls *ctrl_nls);
int NlsStopPermanentLtThreads(struct og_ctrl_nls *ctrl_nls);
int NlsFlushPermanentLtThreads(struct og_ctrl_nls *ctrl_nls);

/** nlslt.c **/
int OgListeningThread(void *ptr);
og_status NlsLtInit(struct og_listening_thread *lt);
og_status NlsLtFlush(struct og_listening_thread *lt);
og_status NlsLtReset(struct og_listening_thread *lt);
og_status OgNlsLtReleaseCurrentRunnning(struct og_listening_thread * lt);

/** nlslog.c **/
og_status NlsRequestLog(struct og_listening_thread *lt, og_string function_name, og_string label,
    int additional_log_flags);
og_status NlsThrowError(struct og_listening_thread *lt, og_string format, ...);
og_status NlsJSONThrowError(struct og_listening_thread *lt, og_string function_name, json_error_t * error);
og_status NlsMainThrowError(og_nls ctrl_nls, og_string format, ...);

/** nlsler.c **/
og_status OgListeningThreadError(struct og_listening_thread *lt);

/** nlsconf.c **/
og_status NlsConfReadFile(struct og_ctrl_nls *ctrl_nls, int init);
og_status NlsConfReadEnv(struct og_ctrl_nls *ctrl_nl);

/** nlsltu.c **/
og_bool OgListeningThreadAnswerUci(struct og_listening_thread *lt);

/** nlsonem.c **/
og_status NlsOnEmergency(struct og_ctrl_nls *ctrl_nls);

/** nlsmt.c **/
int OgMaintenanceThread(void *ptr);
og_status OgMaintenanceThreadStop(struct og_maintenance_thread *mt);
og_status OgMaintenanceThreadInit(struct og_ctrl_nls *ctrl_nls);
og_status OgMaintenanceThreadFlush(struct og_maintenance_thread *mt);

/** nls_endpoints.c **/
og_bool OgNlsEndpoints(struct og_listening_thread *lt, struct og_nls_request *request, struct og_nls_response *response);
og_status OgNlsEndpointsCommonParameters(struct og_listening_thread *lt, struct og_nls_request *request);
og_status OgNlsEndpointsParseParameters(struct og_listening_thread *lt, og_string url, struct og_nls_request *request);
og_status OgNlsEndpointsParseParametersInUrlPath(struct og_listening_thread *lt, struct og_nls_request *request,
    og_string format);
og_status OgNlsEndpointsMemoryReset(struct og_listening_thread *lt);

/** nls_endpoint_test.c **/
og_status NlsEndpointTest(struct og_listening_thread *lt, struct og_nls_request *request,
    struct og_nls_response *response);
og_status NlsEndpointDump(struct og_listening_thread *lt, struct og_nls_request *request,
    struct og_nls_response *response);

/** nls_endpoint_interpret.c **/
og_status NlsEndpointInterpret(struct og_listening_thread *lt, struct og_nls_request *request,
    struct og_nls_response *response);

/** nls_endpoint_packages.c **/
og_status NlsEndpointPackagesPost(struct og_listening_thread *lt, struct og_nls_request *request,
    struct og_nls_response *response);
og_status NlsEndpointPackagesDelete(struct og_listening_thread *lt, struct og_nls_request *request,
    struct og_nls_response *response);

/** nls_endpoint_list.c **/
og_status NlsEndpointList(struct og_listening_thread *lt, struct og_nls_request *request,
    struct og_nls_response *response);

/** nls_endpoint_ready.c **/
og_status NlsEndpointReadyGet(struct og_listening_thread *lt, struct og_nls_request *request,
    struct og_nls_response *response);
og_status NlsEndpointReadySet(struct og_listening_thread *lt, struct og_nls_request *request,
    struct og_nls_response *response);

/** nlsimport.c **/
og_status NlsReadImportFiles(og_nls ctrl_nls);

