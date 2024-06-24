#include <nokogiri.h>

VALUE cNokogiriXmlRelaxNG;

static void
xml_relax_ng_deallocate(void *data)
{
  xmlRelaxNGPtr schema = data;
  xmlRelaxNGFree(schema);
}

static const rb_data_type_t xml_relax_ng_type = {
  .wrap_struct_name = "xmlRelaxNG",
  .function = {
    .dfree = xml_relax_ng_deallocate,
  },
  .flags = RUBY_TYPED_FREE_IMMEDIATELY | RUBY_TYPED_WB_PROTECTED,
};

/*
 * call-seq:
 *  validate_document(document)
 *
 * Validate a Nokogiri::XML::Document against this RelaxNG schema.
 */
static VALUE
validate_document(VALUE self, VALUE document)
{
  xmlDocPtr doc;
  xmlRelaxNGPtr schema;
  VALUE errors;
  xmlRelaxNGValidCtxtPtr valid_ctxt;

  TypedData_Get_Struct(self, xmlRelaxNG, &xml_relax_ng_type, schema);
  doc = noko_xml_document_unwrap(document);

  errors = rb_ary_new();

  valid_ctxt = xmlRelaxNGNewValidCtxt(schema);

  if (NULL == valid_ctxt) {
    /* we have a problem */
    rb_raise(rb_eRuntimeError, "Could not create a validation context");
  }

  xmlRelaxNGSetValidStructuredErrors(
    valid_ctxt,
    noko__error_array_pusher,
    (void *)errors
  );

  xmlRelaxNGValidateDoc(valid_ctxt, doc);

  xmlRelaxNGFreeValidCtxt(valid_ctxt);

  return errors;
}

static VALUE
xml_relax_ng_parse_schema(
  VALUE rb_class,
  xmlRelaxNGParserCtxtPtr c_parser_context,
  VALUE rb_parse_options
)
{
  VALUE rb_errors;
  VALUE rb_schema;
  xmlRelaxNGPtr c_schema;
  libxmlStructuredErrorHandlerState handler_state;

  if (NIL_P(rb_parse_options)) {
    rb_parse_options = rb_const_get_at(
                         rb_const_get_at(mNokogiriXml, rb_intern("ParseOptions")),
                         rb_intern("DEFAULT_SCHEMA")
                       );
  }

  rb_errors = rb_ary_new();

  noko__structured_error_func_save_and_set(&handler_state, (void *)rb_errors, noko__error_array_pusher);
  xmlRelaxNGSetParserStructuredErrors(
    c_parser_context,
    noko__error_array_pusher,
    (void *)rb_errors
  );

  c_schema = xmlRelaxNGParse(c_parser_context);

  xmlRelaxNGFreeParserCtxt(c_parser_context);
  noko__structured_error_func_restore(&handler_state);

  if (NULL == c_schema) {
    VALUE exception = rb_funcall(cNokogiriXmlSyntaxError, rb_intern("aggregate"), 1, rb_errors);

    if (RB_TEST(exception)) {
      rb_exc_raise(exception);
    } else {
      rb_raise(rb_eRuntimeError, "Could not parse document");
    }
  }

  rb_schema = TypedData_Wrap_Struct(rb_class, &xml_relax_ng_type, c_schema);
  rb_iv_set(rb_schema, "@errors", rb_errors);
  rb_iv_set(rb_schema, "@parse_options", rb_parse_options);

  return rb_schema;
}

/*
 * call-seq:
 *  read_memory(string)
 *
 * Create a new RelaxNG from the contents of +string+
 */
static VALUE
read_memory(int argc, VALUE *argv, VALUE rb_class)
{
  VALUE rb_content;
  VALUE rb_parse_options;
  xmlRelaxNGParserCtxtPtr c_parser_context;

  rb_scan_args(argc, argv, "11", &rb_content, &rb_parse_options);

  c_parser_context = xmlRelaxNGNewMemParserCtxt(
                       (const char *)StringValuePtr(rb_content),
                       (int)RSTRING_LEN(rb_content)
                     );

  return xml_relax_ng_parse_schema(rb_class, c_parser_context, rb_parse_options);
}

/*
 * call-seq:
 *  from_document(doc)
 *
 * Create a new RelaxNG schema from the Nokogiri::XML::Document +doc+
 */
static VALUE
from_document(int argc, VALUE *argv, VALUE rb_class)
{
  VALUE rb_document;
  VALUE rb_parse_options;
  xmlDocPtr c_document;
  xmlRelaxNGParserCtxtPtr c_parser_context;

  rb_scan_args(argc, argv, "11", &rb_document, &rb_parse_options);

  c_document = noko_xml_document_unwrap(rb_document);
  c_document = c_document->doc; /* In case someone passes us a node. ugh. */

  c_parser_context = xmlRelaxNGNewDocParserCtxt(c_document);

  return xml_relax_ng_parse_schema(rb_class, c_parser_context, rb_parse_options);
}

void
noko_init_xml_relax_ng(void)
{
  assert(cNokogiriXmlSchema);
  cNokogiriXmlRelaxNG = rb_define_class_under(mNokogiriXml, "RelaxNG", cNokogiriXmlSchema);

  rb_define_singleton_method(cNokogiriXmlRelaxNG, "read_memory", read_memory, -1);
  rb_define_singleton_method(cNokogiriXmlRelaxNG, "from_document", from_document, -1);

  rb_define_private_method(cNokogiriXmlRelaxNG, "validate_document", validate_document, 1);
}
