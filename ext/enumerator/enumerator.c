/************************************************

  enumerator.c - provides Enumerator class

  $Author$

  Copyright (C) 2001-2003 Akinori MUSHA

  $Idaemons: /home/cvs/rb/enumerator/enumerator.c,v 1.1.1.1 2001/07/15 10:12:48 knu Exp $
  $RoughId: enumerator.c,v 1.6 2003/07/27 11:03:24 nobu Exp $
  $Id$

************************************************/

#include "ruby.h"
#include "node.h"

static VALUE rb_cEnumerator;
static ID sym_each, sym_each_with_index, sym_each_slice, sym_each_cons;
static ID id_new, id_enum_obj, id_enum_method, id_enum_args;

static VALUE
obj_to_enum(obj, enum_args)
    VALUE obj, enum_args;
{
    rb_ary_unshift(enum_args, obj);

    return rb_apply(rb_cEnumerator, id_new, enum_args);
}

static VALUE
enumerator_enum_with_index(obj)
    VALUE obj;
{
    return rb_funcall(rb_cEnumerator, id_new, 2, obj, sym_each_with_index);
}

static VALUE
each_slice_i(val, memo)
    VALUE val;
    NODE *memo;
{
    VALUE ary = memo->u1.value;
    long size = memo->u3.cnt;

    rb_ary_push(ary, val);

    if (RARRAY(ary)->len == size) {
	rb_yield(ary);
	memo->u1.value = rb_ary_new2(size);
    }

    return Qnil;
}

static VALUE
enum_each_slice(obj, n)
    VALUE obj, n;
{
    long size = NUM2LONG(n);
    NODE *memo;
    VALUE ary;

    if (size <= 0) rb_raise(rb_eArgError, "invalid slice size");

    memo = rb_node_newnode(NODE_MEMO, rb_ary_new2(size), 0, size);

    rb_iterate(rb_each, obj, each_slice_i, (VALUE)memo);

    ary = memo->u1.value;
    if (RARRAY(ary)->len > 0) rb_yield(ary);

    rb_gc_force_recycle((VALUE)memo);
    return Qnil;
}

static VALUE
enumerator_enum_slice(obj, n)
    VALUE obj, n;
{
    return rb_funcall(rb_cEnumerator, id_new, 3, obj, sym_each_slice, n);
}

static VALUE
each_cons_i(val, memo)
    VALUE val;
    NODE *memo;
{
    VALUE ary = memo->u1.value;
    long size = memo->u3.cnt;
    long len = RARRAY(ary)->len;

    if (len == size) {
	rb_ary_shift(ary);
	rb_ary_push(ary, val);
	rb_yield(ary);
    } else {
	rb_ary_push(ary, val);
	if (len + 1 == size) rb_yield(ary);
    }
    return Qnil;
}

static VALUE
enum_each_cons(obj, n)
    VALUE obj, n;
{
    long size = NUM2LONG(n);
    NODE *memo;
    VALUE ary;

    if (size <= 0) rb_raise(rb_eArgError, "invalid size");
    memo = rb_node_newnode(NODE_MEMO, rb_ary_new2(size), 0, size);

    rb_iterate(rb_each, obj, each_cons_i, (VALUE)memo);

    rb_gc_force_recycle((VALUE)memo);
    return Qnil;
}

static VALUE
enumerator_enum_cons(obj, n)
    VALUE obj, n;
{
    return rb_funcall(rb_cEnumerator, id_new, 3, obj, sym_each_cons, n);
}

static VALUE
enumerator_initialize(argc, argv, obj)
    int argc;
    VALUE *argv;
    VALUE obj;
{
    VALUE enum_obj, enum_method, enum_args;

    rb_scan_args(argc, argv, "11*", &enum_obj, &enum_method, &enum_args);

    if (enum_method == Qnil)
	enum_method = sym_each;

    rb_ivar_set(obj, id_enum_obj, enum_obj);
    rb_ivar_set(obj, id_enum_method, enum_method);
    rb_ivar_set(obj, id_enum_args, enum_args);

    return Qnil;
}

static VALUE
enumerator_iter(memo)
    NODE *memo;
{
    return rb_apply(memo->u1.value, memo->u2.id, memo->u3.value);
}

static VALUE
enumerator_each(obj)
    VALUE obj;
{
    VALUE val;

    obj = (VALUE)rb_node_newnode(NODE_MEMO,
				 rb_ivar_get(obj, id_enum_obj),
				 rb_to_id(rb_ivar_get(obj, id_enum_method)),
				 rb_ivar_get(obj, id_enum_args));
    val = rb_iterate((VALUE (*)_((VALUE)))enumerator_iter, obj, rb_yield, 0);
    rb_gc_force_recycle(obj);
    return val;
}

void
Init_enumerator()
{
    VALUE rb_mEnumerable;

    rb_define_method(rb_mKernel, "to_enum", obj_to_enum, -2);
    rb_define_method(rb_mKernel, "enum_for", obj_to_enum, -2);

    rb_mEnumerable = rb_path2class("Enumerable");

    rb_define_method(rb_mEnumerable, "enum_with_index", enumerator_enum_with_index, 0);
    rb_define_method(rb_mEnumerable, "each_slice", enum_each_slice, 1);
    rb_define_method(rb_mEnumerable, "enum_slice", enumerator_enum_slice, 1);
    rb_define_method(rb_mEnumerable, "each_cons", enum_each_cons, 1);
    rb_define_method(rb_mEnumerable, "enum_cons", enumerator_enum_cons, 1);

    rb_cEnumerator = rb_define_class_under(rb_mEnumerable, "Enumerator", rb_cObject);
    rb_include_module(rb_cEnumerator, rb_mEnumerable);

    rb_define_method(rb_cEnumerator, "initialize", enumerator_initialize, -1);
    rb_define_method(rb_cEnumerator, "each", enumerator_each, 0);

    sym_each		= ID2SYM(rb_intern("each"));
    sym_each_with_index	= ID2SYM(rb_intern("each_with_index"));
    sym_each_slice	= ID2SYM(rb_intern("each_slice"));
    sym_each_cons	= ID2SYM(rb_intern("each_cons"));

    id_new		= rb_intern("new");
    id_enum_obj		= rb_intern("enum_obj");
    id_enum_method	= rb_intern("enum_method");
    id_enum_args	= rb_intern("enum_args");
}
