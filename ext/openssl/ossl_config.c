/*
 * $Id$
 * 'OpenSSL for Ruby' project
 * Copyright (C) 2001-2002  Michal Rokos <m.rokos@sh.cvut.cz>
 * All rights reserved.
 */
/*
 * This program is licenced under the same licence as Ruby.
 * (See the file 'LICENCE'.)
 */
#include "ossl.h"

#define WrapConfig(klass, obj, conf) do { \
    if (!conf) { \
	ossl_raise(rb_eRuntimeError, "Config wasn't intitialized!"); \
    } \
    obj = Data_Wrap_Struct(klass, 0, NCONF_free, conf); \
} while (0)
#define GetConfig(obj, conf) do { \
    Data_Get_Struct(obj, CONF, conf); \
    if (!conf) { \
	ossl_raise(rb_eRuntimeError, "Config wasn't intitialized!"); \
    } \
} while (0)
#define SafeGetConfig(obj, conf) do { \
    OSSL_Check_Kind(obj, cConfig); \
    GetConfig(obj, conf); \
} while(0);

/*
 * Classes
 */
VALUE cConfig;
VALUE eConfigError;

/* 
 * Public 
 */

static CONF *parse_config(VALUE, CONF*);

CONF *
GetConfigPtr(VALUE obj)
{
    CONF *conf;

    SafeGetConfig(obj, conf);

    return conf;
}

CONF *
DupConfigPtr(VALUE obj)
{
    VALUE str;

    OSSL_Check_Kind(obj, cConfig);
    str = rb_funcall(obj, rb_intern("to_s"), 0);

    return parse_config(str, NULL);
}

/*
 * Private
 */
static CONF *
parse_config(VALUE str, CONF *dst)
{
    CONF *conf;
    BIO *bio;
    long eline = -1;

    bio = ossl_obj2bio(str);
    conf = dst ? dst : NCONF_new(NULL);
    if(!conf){
	BIO_free(bio);
	ossl_raise(eConfigError, NULL);
    }
    if(!NCONF_load_bio(conf, bio, &eline)){
	BIO_free(bio);
	if(!dst) NCONF_free(conf);
	if (eline <= 0) ossl_raise(eConfigError, "wrong config format");
	else ossl_raise(eConfigError, "error in line %d", eline);
	ossl_raise(eConfigError, NULL);
    }
    BIO_free(bio);

    return conf;
}

static VALUE
ossl_config_s_parse(VALUE klass, VALUE str)
{
    CONF *conf;
    VALUE obj;

    conf = parse_config(str, NULL);
    WrapConfig(klass, obj, conf);

    return obj;
}

static VALUE
ossl_config_s_alloc(VALUE klass)
{
    CONF *conf;
    VALUE obj;

    if(!(conf = NCONF_new(NULL)))
	ossl_raise(eConfigError, NULL);
    WrapConfig(klass, obj, conf);

    return obj;
}

static VALUE
ossl_config_copy(VALUE self, VALUE other)
{
    VALUE str;
    CONF *conf;

    GetConfig(other, conf);
    str = rb_funcall(self, rb_intern("to_s"), 0);
    parse_config(str, conf);

    return self;
}

static VALUE
ossl_config_initialize(int argc, VALUE *argv, VALUE self)
{
    CONF *conf;
    long eline = -1;
    char *filename;
    VALUE path;

    GetConfig(self, conf);
    rb_scan_args(argc, argv, "01", &path);
    if(!NIL_P(path)){
	SafeStringValue(path);
        filename = StringValuePtr(path);
	if (!NCONF_load(conf, filename, &eline)){
	    if (eline <= 0)
		ossl_raise(eConfigError, "wrong config file %s", filename);
	    else
		ossl_raise(eConfigError, "error in %s:%d", filename, eline);
        }
    }
#ifdef OSSL_NO_CONF_API
    else rb_raise(rb_eArgError, "wrong number of arguments(0 for 1)");
#else
    else _CONF_new_data(conf);
#endif
    
    return self;
}

static VALUE
ossl_config_add_value(VALUE self, VALUE section, VALUE name, VALUE value)
{
#ifdef OSSL_NO_CONF_API
    rb_notimplement();
#else
    CONF *conf;
    CONF_VALUE *sv, *cv;

    GetConfig(self, conf);
    StringValue(section);
    StringValue(name);
    StringValue(value);
    if(!(sv = _CONF_get_section(conf, RSTRING(section)->ptr))){
	if(!(sv = _CONF_new_section(conf, RSTRING(section)->ptr))){
	    ossl_raise(eConfigError, NULL);
	}
    }
    if(!(cv = OPENSSL_malloc(sizeof(CONF_VALUE)))){
	ossl_raise(eConfigError, NULL);
    }
    cv->name = BUF_strdup(RSTRING(name)->ptr);
    cv->value = BUF_strdup(RSTRING(value)->ptr);
    if(!cv->name || !cv->value || !_CONF_add_string(conf, sv, cv)){
	OPENSSL_free(cv->name);
	OPENSSL_free(cv->value);
	OPENSSL_free(cv);
	ossl_raise(eConfigError, "_CONF_add_string failure");
    }
    
    return value;
#endif
}

static VALUE
ossl_config_get_value(VALUE self, VALUE section, VALUE name)
{
    CONF *conf;
    char *str;

    GetConfig(self, conf);
    StringValue(section);
    StringValue(name);
    str = NCONF_get_string(conf, RSTRING(section)->ptr, RSTRING(name)->ptr);
    if(!str){
	ERR_clear_error();
	return Qnil;
    }

    return rb_str_new2(str);
}

static VALUE
ossl_config_get_value_old(int argc, VALUE *argv, VALUE self)
{
    VALUE section, name;
    
    rb_scan_args(argc, argv, "11", &section, &name);

    /* support conf.value(nil, "HOME") -> conf.get_value("", "HOME") */
    if (NIL_P(section)) section = rb_str_new2("");
    /* support conf.value("HOME") -> conf.get_value("", "HOME") */
    if (NIL_P(name)) {
	name = section;
	section = rb_str_new2("");
    }
    /* NOTE: Don't care about conf.get_value(nil, nil) */
    rb_warn("Config#value is deprecated; use Config#get_value");
    return ossl_config_get_value(self, section, name);
}

static VALUE
set_conf_section_i(VALUE i, VALUE *arg)
{
    VALUE name, value;

    Check_Type(i, T_ARRAY);
    name = rb_ary_entry(i, 0);
    value = rb_ary_entry(i, 1);
    ossl_config_add_value(arg[0], arg[1], name, value);

    return Qnil;
}

static VALUE
ossl_config_set_section(VALUE self, VALUE section, VALUE hash)
{
    VALUE arg[2] = { self, section };
    rb_iterate(rb_each, hash, set_conf_section_i, (VALUE)arg);
    return hash;
}

/*
 * Get all numbers as strings - use str.to_i to convert
 * long number = CONF_get_number(confp->config, sect, StringValuePtr(item));
 */
static VALUE
ossl_config_get_section(VALUE self, VALUE section)
{
    CONF *conf;
    STACK_OF(CONF_VALUE) *sk;
    CONF_VALUE *entry;
    int i, entries;
    VALUE hash;

    hash = rb_hash_new();
    GetConfig(self, conf);
    if (!(sk = NCONF_get_section(conf, StringValuePtr(section)))) {
	ERR_clear_error();
	return hash;
    }
    if ((entries = sk_CONF_VALUE_num(sk)) < 0) {
	OSSL_Debug("# of items in section is < 0?!?");
	return hash;
    }
    for (i=0; i<entries; i++) {
	entry = sk_CONF_VALUE_value(sk, i);		
	rb_hash_aset(hash, rb_str_new2(entry->name), rb_str_new2(entry->value));
    }

    return hash;
}

static VALUE
ossl_config_get_section_old(VALUE self, VALUE section)
{
    rb_warn("Config#section is deprecated; use Config#[]");
    return ossl_config_get_section(self, section);
}

#ifdef IMPLEMENT_LHASH_DOALL_ARG_FN
static void
get_conf_section(CONF_VALUE *cv, VALUE ary)
{
    if(cv->name) return;
    rb_ary_push(ary, rb_str_new2(cv->section));
}

static IMPLEMENT_LHASH_DOALL_ARG_FN(get_conf_section, CONF_VALUE*, VALUE);

static VALUE
ossl_config_get_sections(VALUE self)
{
    CONF *conf;
    VALUE ary;

    GetConfig(self, conf);
    ary = rb_ary_new();
    lh_doall_arg(conf->data, LHASH_DOALL_ARG_FN(get_conf_section), (void*)ary);

    return ary;
}
#else
static VALUE
ossl_config_get_sections(VALUE self)
{
    rb_warn("Config::sections don't work with %s", OPENSSL_VERSION_TEXT);
    return rb_ary_new();
}
#endif

#ifdef IMPLEMENT_LHASH_DOALL_ARG_FN
static void
dump_conf_value(CONF_VALUE *cv, VALUE str)
{
    STACK_OF(CONF_VALUE) *sk;
    CONF_VALUE *v;
    int i, num;

    if (cv->name) return;
    sk = (STACK_OF(CONF_VALUE)*)cv->value;
    num = sk_CONF_VALUE_num(sk);
    rb_str_cat2(str, "[ ");
    rb_str_cat2(str, cv->section);
    rb_str_cat2(str, " ]\n");
    for(i = 0; i < num; i++){
	v = sk_CONF_VALUE_value(sk, i);
	rb_str_cat2(str, v->name ? v->name : "None");
	rb_str_cat2(str, "=");
	rb_str_cat2(str, v->value ? v->value : "None");
	rb_str_cat2(str, "\n");
    }
    rb_str_cat2(str, "\n");
}

static IMPLEMENT_LHASH_DOALL_ARG_FN(dump_conf_value, CONF_VALUE*, VALUE);

static VALUE
dump_conf(CONF *conf)
{
    VALUE str;

    str = rb_str_new(0, 0);
    lh_doall_arg(conf->data, LHASH_DOALL_ARG_FN(dump_conf_value), (void*)str);

    return str;
}

static VALUE
ossl_config_to_s(VALUE self)
{
    CONF *conf;

    GetConfig(self, conf);

    return dump_conf(conf);
}
#else
static VALUE
ossl_config_to_s(VALUE self)
{
    rb_warn("Config::to_s don't work with %s", OPENSSL_VERSION_TEXT);
    return rb_str_new(0, 0);
}
#endif

static VALUE
ossl_config_inspect(VALUE self)
{
    VALUE str, ary = ossl_config_get_sections(self);
    char *cname = rb_class2name(rb_obj_class(self));

    str = rb_str_new2("#<");
    rb_str_cat2(str, cname);
    rb_str_cat2(str, " sections=");
    rb_str_append(str, rb_inspect(ary));
    rb_str_cat2(str, ">");

    return str;
}

/*
 * INIT
 */
void
Init_ossl_config()
{
    eConfigError = rb_define_class_under(mOSSL, "ConfigError", eOSSLError);
    cConfig = rb_define_class_under(mOSSL, "Config", rb_cObject);

    rb_define_const(cConfig, "DEFAULT_CONFIG_FILE",
		    rb_str_new2(CONF_get1_default_config_file()));
    rb_define_singleton_method(cConfig, "parse", ossl_config_s_parse, 1);
    rb_define_alias(CLASS_OF(cConfig), "load", "new");
    rb_define_alloc_func(cConfig, ossl_config_s_alloc);
    rb_define_copy_func(cConfig, ossl_config_copy);
    rb_define_method(cConfig, "initialize", ossl_config_initialize, -1);
    rb_define_method(cConfig, "get_value", ossl_config_get_value, 2);
    rb_define_method(cConfig, "value", ossl_config_get_value_old, -1);
    rb_define_method(cConfig, "add_value", ossl_config_add_value, 3);
    rb_define_method(cConfig, "[]", ossl_config_get_section, 1);
    rb_define_method(cConfig, "section", ossl_config_get_section_old, 1);
    rb_define_method(cConfig, "[]=", ossl_config_set_section, 2);
    rb_define_method(cConfig, "sections", ossl_config_get_sections, 0);
    rb_define_method(cConfig, "to_s", ossl_config_to_s, 0);
    rb_define_method(cConfig, "inspect", ossl_config_inspect, 0);
}
