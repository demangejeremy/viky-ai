/*
 *  Sorting recursive request expressions by position
 *  Copyright (c) 2018 Pertimm, by Patrick Constant
 *  Dev : February 2018
 *  Version 1.0
 */
#include "ogm_nlp.h"

#define DOgNlpReInList 0x10

struct re_in_list
{
  struct request_expression *mother_request_expression;
  struct request_input_part *request_input_part;
  int Iorip;
  int Ioriginal_request_input_part_from;
};

struct re_to_sort
{
  int Ire_in_list;
  int start_position, length_position;
};

static og_status NlpRequestExpressionListsSortReset(og_nlp_th ctrl_nlp_th);
static og_status NlpRequestExpressionListsSortRecursive(og_nlp_th ctrl_nlp_th,
    struct request_expression *root_request_expression, struct request_expression *request_expression);
static og_status NlpRequestExpressionListSort(og_nlp_th ctrl_nlp_th, struct request_expression *request_expression);
static og_status NlpRequestExpressionListSortRecursive(og_nlp_th ctrl_nlp_th,
    struct request_expression *root_request_expression, struct request_expression *request_expression);
static og_status NlpRequestExpressionListAdd(og_nlp_th ctrl_nlp_th, struct request_expression *request_expression,
    struct request_input_part *request_input_part, int Iorip);
static int NlpRequestExpressionListCmp(gconstpointer ptr_re_to_sort1, gconstpointer ptr_re_to_sort2, gpointer user_data);

og_status NlpRequestExpressionListsSortInit(og_nlp_th ctrl_nlp_th, og_string name)
{
  og_char_buffer nlpc_name[DPcPathSize];

  snprintf(nlpc_name, DPcPathSize, "%s_re_in_list", name);
  ctrl_nlp_th->hre_in_list = OgHeapInit(ctrl_nlp_th->hmsg, nlpc_name, sizeof(struct re_in_list), DOgNlpReInList);
  IFN(ctrl_nlp_th->hre_in_list)
  {
    NlpThrowErrorTh(ctrl_nlp_th, "NlpRequestExpressionListsSortInit : error on OgHeapInit(%s)", nlpc_name);
    DPcErr;
  }

  snprintf(nlpc_name, DPcPathSize, "%s_re_to_sort", name);
  ctrl_nlp_th->hre_to_sort = OgHeapInit(ctrl_nlp_th->hmsg, nlpc_name, sizeof(struct re_to_sort), DOgNlpReInList);
  IFN(ctrl_nlp_th->hre_to_sort)
  {
    NlpThrowErrorTh(ctrl_nlp_th, "NlpRequestExpressionListsSortInit : error on OgHeapInit(%s)", nlpc_name);
    DPcErr;
  }

  DONE;
}

og_status NlpRequestExpressionListsSortFlush(og_nlp_th ctrl_nlp_th)
{
  IFE(OgHeapFlush(ctrl_nlp_th->hre_in_list));
  IFE(OgHeapFlush(ctrl_nlp_th->hre_to_sort));
  DONE;
}

static og_status NlpRequestExpressionListsSortReset(og_nlp_th ctrl_nlp_th)
{
  IFE(OgHeapReset(ctrl_nlp_th->hre_in_list));
  IFE(OgHeapReset(ctrl_nlp_th->hre_to_sort));
  DONE;
}

og_status NlpRequestExpressionListsSort(og_nlp_th ctrl_nlp_th, struct request_expression *request_expression)
{
  if (ctrl_nlp_th->loginfo->trace & DOgNlpTraceMatch)
  {
    NlpLog(DOgNlpTraceMatch, "NlpRequestExpressionListsSort: before:");
    NlpInterpretTreeLog(ctrl_nlp_th, request_expression, 0);
  }

  IFE(NlpRequestExpressionListsSortRecursive(ctrl_nlp_th, request_expression, request_expression));

  if (ctrl_nlp_th->loginfo->trace & DOgNlpTraceMatch)
  {
    NlpLog(DOgNlpTraceMatch, "NlpRequestExpressionListsSort: after:");
    NlpInterpretTreeLog(ctrl_nlp_th, request_expression, 0);
  }

  DONE;
}

static og_status NlpRequestExpressionListsSortRecursive(og_nlp_th ctrl_nlp_th,
    struct request_expression *root_request_expression, struct request_expression *request_expression)
{

  if (request_expression == root_request_expression && request_expression->expression->interpretation->is_recursive)
  {
    IFE(NlpRequestExpressionListSort(ctrl_nlp_th, request_expression));
  }
  else
  {
    for (int i = 0; i < request_expression->orips_nb; i++)
    {
      struct request_input_part *request_input_part = NlpGetRequestInputPart(ctrl_nlp_th, request_expression, i);
      IFN(request_input_part) DPcErr;

      if (request_input_part->type == nlp_input_part_type_Interpretation)
      {
        struct request_expression *sub_request_expression = OgHeapGetCell(ctrl_nlp_th->hrequest_expression,
            request_input_part->Irequest_expression);
        IFN(sub_request_expression) DPcErr;

        if (!request_expression->expression->is_recursive
            && sub_request_expression->expression->interpretation->is_recursive)
        {
          IFE(NlpRequestExpressionListSort(ctrl_nlp_th, sub_request_expression));
        }

        IFE(NlpRequestExpressionListsSortRecursive(ctrl_nlp_th, root_request_expression, sub_request_expression));
      }
    }
  }

  DONE;
}

static og_status NlpRequestExpressionListSort(og_nlp_th ctrl_nlp_th, struct request_expression *request_expression)
{
  IFE(NlpRequestExpressionListsSortReset(ctrl_nlp_th));
  g_queue_clear(request_expression->sorted_flat_list);
  IFE(NlpRequestExpressionListSortRecursive(ctrl_nlp_th, request_expression, request_expression));

  int re_to_sort_used = OgHeapGetCellsUsed(ctrl_nlp_th->hre_to_sort);
  struct re_to_sort *re_to_sorts = OgHeapGetCell(ctrl_nlp_th->hre_to_sort, 0);
  IFN(re_to_sorts) DPcErr;

  g_qsort_with_data(re_to_sorts, re_to_sort_used, sizeof(struct re_to_sort), NlpRequestExpressionListCmp, ctrl_nlp_th);

  int re_in_list_used = OgHeapGetCellsUsed(ctrl_nlp_th->hre_in_list);
  struct re_in_list *re_in_lists = OgHeapGetCell(ctrl_nlp_th->hre_in_list, 0);
  IFN(re_in_lists) DPcErr;

  if (ctrl_nlp_th->loginfo->trace & DOgNlpTraceMatch)
  {
    OgMsg(ctrl_nlp_th->hmsg, "", DOgMsgDestInLog, "NlpRequestExpressionListSort: working on the following expression:");
    IFE(NlpInterpretTreeLog(ctrl_nlp_th, request_expression, 0));

    OgMsg(ctrl_nlp_th->hmsg, "", DOgMsgDestInLog, "elements of re_in_list:");
    for (int i = 0; i < re_in_list_used; i++)
    {
      struct re_in_list *re_in_list = re_in_lists + i;
      struct request_expression *sub_request_expression = OgHeapGetCell(ctrl_nlp_th->hrequest_expression,
          re_in_list->request_input_part->Irequest_expression);
      IFE(NlpRequestExpressionLog(ctrl_nlp_th, re_in_list->mother_request_expression, 2));
      IFE(NlpRequestExpressionLog(ctrl_nlp_th, sub_request_expression, 4));
    }
    OgMsg(ctrl_nlp_th->hmsg, "", DOgMsgDestInLog, "elements of re_to_sort:");
    for (int i = 0; i < re_in_list_used; i++)
    {
      struct re_to_sort *re_to_sort = re_to_sorts + i;
      OgMsg(ctrl_nlp_th->hmsg, "", DOgMsgDestInLog, "%2d: %2d %d:%d", i, re_to_sort->Ire_in_list,
          re_to_sort->start_position, re_to_sort->length_position);
    }
  }

  // setting the sorted_flat_list GQueue
  for (int i = 0; i < re_in_list_used; i++)
  {
    struct re_to_sort *re_to_sort = re_to_sorts + i;
    struct re_in_list *re_in_list = re_in_lists + re_to_sort->Ire_in_list;
    g_queue_push_tail(request_expression->sorted_flat_list,
        GINT_TO_POINTER(re_in_list->request_input_part->Irequest_expression));
  }

  if (ctrl_nlp_th->loginfo->trace & DOgNlpTraceMatch)
  {
    OgMsg(ctrl_nlp_th->hmsg, "", DOgMsgDestInLog, "NlpRequestExpressionListSort: sorted flat list:");
    for (GList *iter = request_expression->sorted_flat_list->head; iter; iter = iter->next)
    {
      int Irequest_expression = GPOINTER_TO_INT(iter->data);
      struct request_expression *sub_request_expression = OgHeapGetCell(ctrl_nlp_th->hrequest_expression,
          Irequest_expression);
      IFE(NlpRequestExpressionLog(ctrl_nlp_th, sub_request_expression, 2));
    }
  }

  DONE;
}

static og_status NlpRequestExpressionListSortRecursive(og_nlp_th ctrl_nlp_th,
    struct request_expression *root_request_expression, struct request_expression *request_expression)
{
  for (int i = 0; i < request_expression->orips_nb; i++)
  {
    struct request_input_part *request_input_part = NlpGetRequestInputPart(ctrl_nlp_th, request_expression, i);
    IFN(request_input_part) DPcErr;

    if (request_input_part->type == nlp_input_part_type_Interpretation)
    {
      struct request_expression *sub_request_expression = OgHeapGetCell(ctrl_nlp_th->hrequest_expression,
          request_input_part->Irequest_expression);
      IFN(sub_request_expression) DPcErr;
      if (request_expression->expression->interpretation->is_recursive
          && !sub_request_expression->expression->is_recursive)
      {
        IFE(NlpRequestExpressionListAdd(ctrl_nlp_th, request_expression, request_input_part, i));
      }
      if (request_expression->expression == sub_request_expression->expression)
      {
        IFE(NlpRequestExpressionListSortRecursive(ctrl_nlp_th, root_request_expression, sub_request_expression));
      }
    }
  }
  DONE;
}

static og_status NlpRequestExpressionListAdd(og_nlp_th ctrl_nlp_th, struct request_expression *request_expression,
    struct request_input_part *request_input_part, int Iorip)
{
  size_t Ire_in_list;
  struct re_in_list *re_in_list = OgHeapNewCell(ctrl_nlp_th->hre_in_list, &Ire_in_list);
  IFn(re_in_list) DPcErr;
  re_in_list->mother_request_expression = request_expression;
  re_in_list->request_input_part = request_input_part;
  re_in_list->Iorip = Iorip;

  size_t Ire_to_sort;
  struct re_to_sort *re_to_sort = OgHeapNewCell(ctrl_nlp_th->hre_to_sort, &Ire_to_sort);
  IFn(re_to_sort) DPcErr;
  re_to_sort->Ire_in_list = Ire_in_list;

  struct request_position *request_position_start = OgHeapGetCell(ctrl_nlp_th->hrequest_position,
      request_input_part->request_position_start);
  struct request_position *request_position_end = OgHeapGetCell(ctrl_nlp_th->hrequest_position,
      request_input_part->request_position_start + request_input_part->request_positions_nb - 1);

  re_to_sort->start_position = request_position_start->start;
  re_to_sort->length_position = request_position_end->start + request_position_end->length
      - request_position_start->start;

  DONE;
}

static int NlpRequestExpressionListCmp(gconstpointer ptr_re_to_sort1, gconstpointer ptr_re_to_sort2, gpointer user_data)
{
  struct re_to_sort *re_to_sort1 = (struct re_to_sort *) ptr_re_to_sort1;
  struct re_to_sort *re_to_sort2 = (struct re_to_sort *) ptr_re_to_sort2;

  if (re_to_sort1->start_position != re_to_sort2->start_position)
  {
    return (re_to_sort1->start_position - re_to_sort2->start_position);
  }
  // to avoid any random in sorting
  return re_to_sort1->Ire_in_list - re_to_sort2->Ire_in_list;
}

