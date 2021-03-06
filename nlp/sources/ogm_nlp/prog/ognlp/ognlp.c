/*
 *  Test program for the Natural Language Processing libognlp.so library.
 *  Copyright (c) 2027 Pertimm by Patrick Constant
 *  Dev : September 2017
 *  Version 1.0
 */
#include <lognlp.h>
#include <logmsg.h>
#include <getopt.h>
#include <logpath.h>
#include <logheap.h>
#include <jansson.h>
#include <glib.h>

#define DOgFileConfOgmSsi_Txt  "conf/ogm_ssi.txt"

struct og_filename
{
  int start;
  int length;
};

/* structure de controle du programme */
struct og_info
{
  void *hmsg, *herr;
  ogmutex_t *hmutex;
  struct og_nlp_param *param;
  og_heap hfilename_ba, hfilename;
  og_nlp hnlp;
  og_nlp_th hnlpi;
  char output_filename[DPcPathSize];
  char interpret_filename[DPcPathSize];
  char packages_directory[DPcPathSize];
  int dump;
};

/* functions for using main api */
static int nlp(struct og_info *info, int argc, char * argv[]);
static int nlp_compile(struct og_info *info, char *json_compilation_filename);
static og_status nlp_dump(struct og_info *info);
static int nlp_interpret(struct og_info *info, char *json_interpret_filename);
static int nlp_send_errors_as_json(struct og_info *info);

/* default function to define */
static int OgUse(struct og_info *);
static void OgExit(struct og_info *);

int main(int argc, char * argv[])
{
  struct og_info info[1];
  struct og_nlp_param param[1];
  time_t ltime;

  /* initialization of program info structure */
  memset(info, 0, sizeof(struct og_info));
  info->param = param;
  IFn(info->hmsg = OgLogInit("ognlp", "ognlp", DOgMsgTraceMinimal + DOgMsgTraceMemory, DOgMsgLogFile)) exit(1);
  info->herr = OgLogGetErr(info->hmsg);
  info->hmutex = OgLogGetMutex(info->hmsg);

  memset(param, 0, sizeof(struct og_nlp_param));
  param->hmsg = info->hmsg;
  param->herr = info->herr;
  param->hmutex = info->hmutex;
  param->loginfo.trace = DOgNlpTraceMinimal + DOgNlpTraceMemory;
  param->loginfo.where = "ognlp";
  gchar *current_dir = g_get_current_dir();
  snprintf(param->WorkingDirectory, DPcPathSize, "%s", current_dir);
  snprintf(param->configuration_file, DPcPathSize, "%s/%s", param->WorkingDirectory, DOgFileConfOgmSsi_Txt);

  g_free(current_dir);

  OgMlogMaxFileSizeSet(0x10000000);

  if (param->loginfo.trace & DOgNlpTraceMinimal)
  {
    time(&ltime);
    OgMsg(info->hmsg, "", DOgMsgDestInLog, "\nProgram %s starting with pid %x at %.24s", OgLogGetModuleName(info->hmsg),
        getpid(), OgGmtime(&ltime));
  }

  IF(nlp(info,argc,argv))
  {
    OgExit(info);
  }

  if (param->loginfo.trace & DOgNlpTraceMinimal)
  {
    time(&ltime);
    OgMsg(info->hmsg, "", DOgMsgDestInLog, "\nProgram %s exiting at %.24s\n", OgLogGetModuleName(info->hmsg),
        OgGmtime(&ltime));
  }

  IFE(OgLogFlush(info->hmsg));

  return (0);
}

static int nlp(struct og_info *info, int argc, char * argv[])
{
  struct og_nlp_param *param = info->param;

  IFn(info->hfilename=OgHeapInit(info->hmsg,"ognlp_filename",sizeof(struct og_filename),0x10)) return (0);
  IFn(info->hfilename_ba=OgHeapInit(info->hmsg,"ognlp_filename_ba",sizeof(unsigned char),0x100)) return (0);

  /* definition of program options */
  struct option longOptions[] = { { "compile", required_argument, NULL, 'c' },   //
      { "interpret", required_argument, NULL, 'i' },   //
      { "output", required_argument, NULL, 'o' },   //
      { "dump", no_argument, NULL, 'd' },   //
      { "help", no_argument, NULL, 'h' },   //
      { "trace", required_argument, NULL, 't' },   //
      { 0, 0, 0, 0 }   //
  };

  char *nil, carlu;
  int optionIndex;

  /* parsing options to exclusion of compilation and interpretation files */
  optionIndex = 0;
  while ((carlu = getopt_long(argc, argv, "c:r:i:o:t:dh?", longOptions, &optionIndex)) != EOF)
  {
    struct og_filename filename[1];
    switch (carlu)
    {
      case 0:
        break;
      case 'c': /* compiling file 'optarg' */
        filename->start = OgHeapGetCellsUsed(info->hfilename_ba);
        filename->length = strlen(optarg);
        IFE(OgHeapAppend(info->hfilename_ba, filename->length + 1, optarg));   // +1 because we want to keep the zero
        IFE(OgHeapAppend(info->hfilename, 1, filename));
        break;
      case 'r': /* directory of packages files 'optarg' */
        strcpy(info->packages_directory, optarg);
        break;
      case 'i': /* interpret file 'optarg' */
        strcpy(info->interpret_filename, optarg);
        break;
      case 'd': /* dump */
        info->dump = TRUE;
        break;
      case 'o': /* output_filename */
        strcpy(info->output_filename, optarg);
        break;
      case 't':
        param->loginfo.trace = strtol(optarg, &nil, 16);
        break;
      case 'h': /* help */
      case '?':
        OgUse(info);
        DONE;
        break;
    }
  }

  info->hnlp = OgNlpInit(info->param);
  IFN(info->hnlp)
  {
    nlp_send_errors_as_json(info);
    DPcErr;
  }

  struct og_nlp_threaded_param nlpi_param[1];
  memset(nlpi_param, 0, sizeof(struct og_nlp_threaded_param));
  nlpi_param->herr = info->param->herr;
  nlpi_param->hmsg = info->param->hmsg;
  nlpi_param->hmutex = info->param->hmutex;
  nlpi_param->loginfo = info->param->loginfo;
  nlpi_param->name = "ognlp";
  info->hnlpi = OgNlpThreadedInit(info->hnlp, nlpi_param);
  IFN(info->hnlpi)
  {
    nlp_send_errors_as_json(info);
    DPcErr;
  }

  int nb_compilation_files = OgHeapGetCellsUsed(info->hfilename);
  for (int i = 0; i < nb_compilation_files; i++)
  {
    struct og_filename *filename = OgHeapGetCell(info->hfilename, i);
    char *compilation_filename = OgHeapGetCell(info->hfilename_ba, filename->start);
    IFE(nlp_compile(info, compilation_filename));
  }

  if (info->packages_directory[0])
  {
    char import_file[DPcPathSize], search_path[DPcPathSize];
    struct og_file str_file[1];
    struct og_stat filestat;
    int retour;

    memset(str_file, 0, sizeof(struct og_file));
    sprintf(search_path, "%s/%s", info->packages_directory, "*.json");
    IFE(retour = OgFindFirstFile(str_file, search_path));
    if (retour)
    {
      do
      {
        sprintf(import_file, "%s/%s", info->packages_directory, str_file->File_Path);
        IFx(OgStat(import_file,DOgStatMask_mtime,&filestat)) continue;
        if (filestat.is_dir) continue;
        IFE(nlp_compile(info, import_file));
      }
      while (OgFindNextFile(str_file));
      OgFindClose(str_file);
    }

  }

  if (info->dump == TRUE)
  {
    if (info->output_filename[0] == 0) sprintf(info->output_filename, "/dev/stdout");
    IFE(nlp_dump(info));
  }

  if (info->interpret_filename[0])
  {
    IFE(nlp_interpret(info, info->interpret_filename));
  }

  IFE(OgNlpThreadedReset(info->hnlpi));
  IFE(OgNlpThreadedFlush(info->hnlpi));
  IFE(OgHeapFlush(info->hfilename_ba));
  IFE(OgHeapFlush(info->hfilename));
  IFE(OgNlpFlush(info->hnlp));

  DONE;
}

static int nlp_compile(struct og_info *info, char *json_compilation_filename)
{
  OgMsg(info->hmsg, "", DOgMsgDestInLog, "Compiling '%s'", json_compilation_filename);

  json_error_t error[1];
  json_auto_t *json = json_load_file(json_compilation_filename, JSON_REJECT_DUPLICATES, error);
  IFN(json)
  {
    char erreur[DPcPathSize];
    sprintf(erreur, "nlp_compile: error while reading '%s': %s", json_compilation_filename, error->text);
    OgErr(info->herr, erreur);
    nlp_send_errors_as_json(info);
    DPcErr;
  }
  struct og_nlp_compile_input input[1];
  struct og_nlp_compile_output output[1];

  memset(input, 0, sizeof(struct og_nlp_compile_input));
  input->json_input = json;

  IF(OgNlpCompile(info->hnlpi, input, output))
  {
    nlp_send_errors_as_json(info);
    DPcErr;
  }

  IFN(output->json_output)
  {
    OgErr(info->herr, "nlp_compile: null output->json_output");
    nlp_send_errors_as_json(info);
    DPcErr;
  }
  else if (!info->interpret_filename[0])
  {
    og_status status = json_dump_file(output->json_output, "/dev/stdout", JSON_INDENT(2));
    printf("\n");
    IF(status)
    {
      OgErr(info->herr, "nlp_compile: error on json_dump_file");
      DPcErr;
    }
  }

  DONE;
}

static og_status nlp_dump(struct og_info *info)
{
  OgMsg(info->hmsg, "", DOgMsgDestInLog, "Dumping '%s'", info->output_filename);

  struct og_nlp_dump_input input[1];
  struct og_nlp_dump_output output[1];

  memset(input, 0, sizeof(struct og_nlp_dump_input));

  IFE(OgNlpDump(info->hnlpi, input, output));

  IFN(output->json_output)
  {
    OgErr(info->herr, "nlp_dump: null output->json_output");
    DPcErr;
  }
  else
  {
    if (info->output_filename != NULL)
    {
      og_status status = json_dump_file(output->json_output, info->output_filename, JSON_INDENT(2));
      IF(status)
      {
        char buffer[DPcPathSize];
        sprintf(buffer, "nlp_dump: error on dump file '%s'", info->output_filename);
        OgErr(info->herr, buffer);
        DPcErr;
      }
    }
  }

  DONE;
}

static int nlp_interpret(struct og_info *info, char *json_interpret_filename)
{
  OgMsg(info->hmsg, "", DOgMsgDestInLog, "Reading '%s'", json_interpret_filename);

  json_error_t error[1];
  json_auto_t *json = json_load_file(json_interpret_filename, JSON_REJECT_DUPLICATES, error);
  IFN(json)
  {
    char erreur[DPcPathSize];
    sprintf(erreur, "nlp_interpret: error while reading '%s': %s", json_interpret_filename, error->text);
    OgErr(info->herr, erreur);
    nlp_send_errors_as_json(info);
    DPcErr;
  }

  IFE(OgNlpThreadedReset(info->hnlpi));

  struct og_nlp_interpret_input input[1];
  struct og_nlp_interpret_output output[1];

  memset(input, 0, sizeof(struct og_nlp_interpret_input));
  input->json_input = json;

  IF(OgNlpInterpret(info->hnlpi, input, output))
  {
    nlp_send_errors_as_json(info);
    DPcErr;
  }

  IFN(output->json_output)
  {
    OgErr(info->herr, "nlp_interpret: null output->json_output");
    nlp_send_errors_as_json(info);
    DPcErr;
  }
  else
  {
    og_status status = json_dump_file(output->json_output, "/dev/stdout", JSON_INDENT(2));
    printf("\n");
    IF(status)
    {
      char buffer[DPcPathSize];
      sprintf(buffer, "nlp_interpret: error on json_dump_file");
      OgErr(info->herr, buffer);
      DPcErr;
    }
  }

  IFE(OgNlpThreadedReset(info->hnlpi));

  DONE;
}

static og_status split_error_message(json_t *json_errors, og_string multiple_errors)
{
  if (multiple_errors == NULL) CONT;

  int imultiple_errors = strlen(multiple_errors);
  char errors[imultiple_errors + 1];
  strncpy(errors, multiple_errors, imultiple_errors + 1);

  char *saveptr = NULL;
  char *error_line = strtok_r(errors, "\n", &saveptr);
  while (error_line != NULL)
  {

    json_array_append_new(json_errors, json_string(error_line));

    error_line = strtok_r(NULL, "\n", &saveptr);
  }

  DONE;
}

static int nlp_send_errors_as_json(struct og_info *info)
{

  json_t * root = NULL;
  IFE(OgNlpThreadedGetCustomError(info->hnlpi, &root));
  if (root == NULL)
  {
    root = json_object();
  }

  json_t * errors = json_array();
  json_object_set_new(root, "errors", errors);

  char erreur[DOgErrorSize];
  while (OgErrLast(info->herr, erreur, 0))
  {
    split_error_message(errors, erreur);
  }

  int h = 0;
  while (PcErrDiag(&h, erreur))
  {
    split_error_message(errors, erreur);
  }

  if (json_array_size(errors) == 0)
  {
    json_array_append_new(errors, json_string("Unexpected errors"));
  }

  json_dump_file(root, "/dev/stdout", JSON_INDENT(2));
  json_decrefp(&root);

  printf("\n");

  DONE;
}

static int OgUse(struct og_info *info)
{
  char buffer[8192];
  int ibuffer = 0;

  ibuffer += sprintf(buffer, "Usage : oginterpret [options]\n");
  ibuffer += sprintf(buffer + ibuffer, "options are:\n");
  ibuffer += sprintf(buffer + ibuffer, "   -c,  --compile=<packages filename>\n");
  ibuffer += sprintf(buffer + ibuffer, "   -r,  --repository=<directory containing packages>\n");
  ibuffer += sprintf(buffer + ibuffer, "   -i,  --interpret=<input_filename>: specify input filename\n");
  ibuffer += sprintf(buffer + ibuffer, "   -o,  --output=<output_filename>: "
      "specify output filename (defaut is stdout)\n");
  ibuffer += sprintf(buffer + ibuffer, "   -h,  --help prints this message\n");
  ibuffer += sprintf(buffer + ibuffer, "   -t<n>: trace options for "
      "logging (default 0x%x)\n", info->param->loginfo.trace);
  ibuffer += sprintf(buffer + ibuffer, "    <n> has a combined hexadecimal value of:\n");
  ibuffer += sprintf(buffer + ibuffer, "      0x1: minimal, 0x2: memory, 0x4: synchro, 0x8: compile\n");
  ibuffer += sprintf(buffer + ibuffer, "      0x10: consolidate, 0x20: interpret, 0x40: dump, 0x80: package\n");
  ibuffer += sprintf(buffer + ibuffer, "      0x100: match, 0x200: parse, 0x400: solution, 0x800: JS\n");
  ibuffer += sprintf(buffer + ibuffer, "      0x1000: ltrac, 0x2000: ltras, 0x4000: ltras detail, 0x8000: group numbers\n");
  ibuffer += sprintf(buffer + ibuffer, "      0x10000: lem, 0x20000: match expression, 0x40000: match expression zone\n");
  OgLogConsole(info->hmsg, "%.*s", ibuffer, buffer);

  DONE;
}

static void OgExit(struct og_info *info)
{
  time_t ltime;
  OgMsgErr(info->hmsg, "ogintepret_error", 0, 0, 0, DOgMsgSeverityEmergency, 0);
  time(&ltime);
  OgMsg(info->hmsg, "", DOgMsgDestInLog + DOgMsgDestInErr + DOgMsgSeverityEmergency,
      "Program %s exiting on error at %.24s\n", OgLogGetModuleName(info->hmsg), OgGmtime(&ltime));

  exit(1);
}

