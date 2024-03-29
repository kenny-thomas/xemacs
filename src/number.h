/* Definitions of numeric types for XEmacs.
   Copyright (C) 2004 Jerry James.

This file is part of XEmacs.

XEmacs is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation, either version 3 of the License, or (at your
option) any later version.

XEmacs is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with XEmacs.  If not, see <http://www.gnu.org/licenses/>. */

/* Synched up with: Not in FSF. */

#ifndef INCLUDED_number_h_
#define INCLUDED_number_h_

/* The following types are always defined in the same manner:
   fixnum       = whatever fits in the Lisp_Object type
   integer      = union (fixnum, bignum)
   rational     = union (integer, ratio)
   float        = C double
   floating     = union(float, bigfloat)  Anybody got a better name?
   real         = union (rational, floating)
   number       = real  (should be union(real, complex) but no complex yet)

   It is up to the library-specific code to define the remaining types,
   namely: bignum, ratio, and bigfloat.  Not all of these types may be
   available.  The top-level configure script should define the symbols
   HAVE_BIGNUM, HAVE_RATIO, and HAVE_BIGFLOAT to indicate which it provides.
   If some type is not defined by the library, this is what happens:

   - bignum: bignump(x) is false for all x; any attempt to create a bignum
     causes an error to be raised.

   - ratio: we define our own structure consisting of two Lisp_Objects, which
     are presumed to be integers (i.e., either fixnums or bignums).  We do our
     own GCD calculation, which is bound to be slow, to keep the ratios
     reduced to canonical form.  (FIXME: Not yet implemented.)

   - bigfloat: bigfloat(x) is false for all x; any attempt to create a
     bigfloat causes an error to be raised.

   We (provide) the following symbols, so that Lisp code has some hope of
   using this correctly:

   - (provide 'bignum) if HAVE_BIGNUM
   - (provde 'ratio) if HAVE_RATIO
   - (provide 'bigfloat) if HAVE_BIGFLOAT
*/

/* Load the library definitions */
#if defined(WITH_GMP) || defined(WITH_MPIR)
#include "number-gmp.h"
#endif
#ifdef WITH_MP
#include "number-mp.h"
#endif


/********************************* Bignums **********************************/
#ifdef HAVE_BIGNUM

struct Lisp_Bignum
{
  FROB_BLOCK_LISP_OBJECT_HEADER lheader;
  bignum data;
};
typedef struct Lisp_Bignum Lisp_Bignum;

DECLARE_LISP_OBJECT (bignum, Lisp_Bignum);
#define XBIGNUM(x) XRECORD (x, bignum, Lisp_Bignum)
#define wrap_bignum(p) wrap_record (p, bignum)
#define BIGNUMP(x) RECORDP (x, bignum)
#define CHECK_BIGNUM(x) CHECK_RECORD (x, bignum)
#define CONCHECK_BIGNUM(x) CONCHECK_RECORD (x, bignum)

#define bignum_data(b) (b)->data
#define XBIGNUM_DATA(x) bignum_data (XBIGNUM (x))

#define BIGNUM_ARITH_RETURN(b,op) do				\
{								\
  Lisp_Object retval = make_bignum (0);				\
  bignum_##op (XBIGNUM_DATA (retval), XBIGNUM_DATA (b));	\
  return Fcanonicalize_number (retval);				\
} while (0)

#define BIGNUM_ARITH_RETURN1(b,op,arg) do			\
{								\
  Lisp_Object retval = make_bignum(0);				\
  bignum_##op (XBIGNUM_DATA (retval), XBIGNUM_DATA (b), arg);	\
  return Fcanonicalize_number (retval);				\
} while (0)

#if SIZEOF_EMACS_INT == SIZEOF_LONG
# define bignum_fits_emacs_int_p(b) bignum_fits_long_p(b)
# define bignum_to_emacs_int(b) bignum_to_long(b)
# define bignum_set_emacs_int bignum_set_long
# define make_bignum_emacs_uint(b) make_bignum_un(b)
#elif SIZEOF_EMACS_INT == SIZEOF_INT
# define bignum_fits_emacs_int_p(b) bignum_fits_int_p(b)
# define bignum_to_emacs_int(b) bignum_to_int(b)
# define bignum_set_emacs_int bignum_set_long
# define make_bignum_emacs_uint(b) make_bignum_un(b)
#else
# define bignum_fits_emacs_int_p(b) bignum_fits_llong_p(b)
# define bignum_to_emacs_int(b) bignum_to_llong(b)
# define bignum_set_emacs_int bignum_set_llong
# define make_bignum_emacs_uint(b) make_bignum_ull(b)
#endif

extern Lisp_Object make_bignum (long);
extern Lisp_Object make_bignum_un (unsigned long);
extern Lisp_Object make_bignum_ll (long long);
extern Lisp_Object make_bignum_ull (unsigned long long);
extern Lisp_Object make_bignum_bg (bignum);
extern bignum scratch_bignum, scratch_bignum2;

#else /* !HAVE_BIGNUM */

#define BIGNUMP(x)         0
#define CHECK_BIGNUM(x)    dead_wrong_type_argument (Qbignump, x)
#define CONCHECK_BIGNUM(x) dead_wrong_type_argument (Qbignump, x)
typedef void bignum;
#define make_bignum(l)     This XEmacs does not support bignums
#define make_bignum_ll(l)  This XEmacs does not support bignums
#define make_bignum_bg(b)  This XEmacs does not support bignums

#endif /* HAVE_BIGNUM */

extern Lisp_Object Qbignump;
EXFUN (Fbignump, 1);


/********************************* Integers *********************************/
/* Qintegerp in lisp.h */
#define INTEGERP(x) (FIXNUMP(x) || BIGNUMP(x))
#define CHECK_INTEGER(x) do {			\
 if (!INTEGERP (x))				\
   dead_wrong_type_argument (Qintegerp, x);	\
 } while (0)
#define CONCHECK_INTEGER(x) do {		\
 if (!INTEGERP (x))				\
   x = wrong_type_argument (Qintegerp, x);	\
}  while (0)

#ifdef HAVE_BIGNUM
#define make_integer(x)							\
  (NUMBER_FITS_IN_A_FIXNUM (x) ? make_fixnum (x)			\
   : (sizeof (x) > SIZEOF_LONG ? make_bignum_ll (x) : make_bignum (x)))
#define make_unsigned_integer(x)					\
  (UNSIGNED_NUMBER_FITS_IN_A_FIXNUM (x) ? make_fixnum (x)		\
   : (sizeof (x) > SIZEOF_LONG ? make_bignum_ull (x) : make_bignum_un (x)))
#else
#define make_integer(x) make_fixnum (x)
#define make_unsigned_integer(x) make_fixnum ((EMACS_INT) x)
#endif

extern Fixnum Vmost_negative_fixnum, Vmost_positive_fixnum;
EXFUN (Fintegerp, 1);
EXFUN (Fevenp, 1);
EXFUN (Foddp, 1);

/* There are varying mathematical definitions of what a natural number is,
   differing about whether 0 is inside or outside the set. The Oxford
   English Dictionary, second edition, does say that they are whole numbers,
   not fractional, but it doesn't give a bound, and gives a quotation
   talking about the natural numbers from 1 to 100. Since 100 is certainly
   *not* the upper bound on natural numbers, we can't take 1 as the lower
   bound from that example. The Real Academia Española's dictionary, not of
   English but certainly sharing the western academic tradition, says of
   "número natural":

   1.  m. Mat. Cada uno de los elementos de la sucesión 0, 1, 2, 3...

   that is, "each of the elements of the succession 0, 1, 2, 3 ...". The
   various Wikipedia articles in languages I can read agree.  It's
   reasonable to call this macro and the associated Lisp function
   NATNUMP. */

#ifdef HAVE_BIGNUM
#define NATNUMP(x) ((FIXNUMP (x) && XFIXNUM (x) >= 0) || \
		    (BIGNUMP (x) && bignum_sign (XBIGNUM_DATA (x)) >= 0))
#else
#define NATNUMP(x) (FIXNUMP (x) && XFIXNUM (x) >= 0)
#endif

#define CHECK_NATNUM(x) do {			\
  if (!NATNUMP (x))				\
    dead_wrong_type_argument (Qnatnump, x);	\
} while (0)

#define CONCHECK_NATNUM(x) do {			\
  if (!NATNUMP (x))				\
    x = wrong_type_argument (Qnatnump, x);	\
} while (0)


/********************************** Ratios **********************************/
#ifdef HAVE_RATIO

struct Lisp_Ratio
{
  FROB_BLOCK_LISP_OBJECT_HEADER lheader;
  ratio data;
};
typedef struct Lisp_Ratio Lisp_Ratio;

DECLARE_LISP_OBJECT (ratio, Lisp_Ratio);
#define XRATIO(x) XRECORD (x, ratio, Lisp_Ratio)
#define wrap_ratio(p) wrap_record (p, ratio)
#define RATIOP(x) RECORDP (x, ratio)
#define CHECK_RATIO(x) CHECK_RECORD (x, ratio)
#define CONCHECK_RATIO(x) CONCHECK_RECORD (x, ratio)

#define ratio_data(r) (r)->data

#define XRATIO_DATA(r) ratio_data (XRATIO (r))
#define XRATIO_NUMERATOR(r) ratio_numerator (XRATIO_DATA (r))
#define XRATIO_DENOMINATOR(r) ratio_denominator (XRATIO_DATA (r))

#define RATIO_ARITH_RETURN(r,op) do			\
{							\
  Lisp_Object retval = make_ratio (0L, 1UL);		\
  ratio_##op (XRATIO_DATA (retval), XRATIO_DATA (r));	\
  return Fcanonicalize_number (retval);			\
} while (0)

#define RATIO_ARITH_RETURN1(r,op,arg) do			\
{								\
  Lisp_Object retval = make_ratio (0L, 1UL);			\
  ratio_##op (XRATIO_DATA (retval), XRATIO_DATA (r), arg);	\
  return Fcanonicalize_number (retval);				\
} while (0)

extern Lisp_Object make_ratio (long, unsigned long);
extern Lisp_Object make_ratio_bg (bignum, bignum);
extern Lisp_Object make_ratio_rt (ratio);
extern ratio scratch_ratio, scratch_ratio2;

#else /* !HAVE_RATIO */

#define RATIOP(x)          0
#define CHECK_RATIO(x)     dead_wrong_type_argument (Qratiop, x)
#define CONCHECK_RATIO(x)  dead_wrong_type_argument (Qratiop, x)
typedef void ratio;
#define make_ratio(n,d)    This XEmacs does not support ratios
#define make_ratio_bg(n,d) This XEmacs does not support ratios

#endif /* HAVE_RATIO */

extern Lisp_Object Qratiop;
EXFUN (Fratiop, 1);


/******************************** Rationals *********************************/
extern Lisp_Object Qrationalp;

#define RATIONALP(x) (INTEGERP(x) || RATIOP(x))
#define CHECK_RATIONAL(x) do {			\
 if (!RATIONALP (x))				\
   dead_wrong_type_argument (Qrationalp, x);	\
 } while (0)
#define CONCHECK_RATIONAL(x) do {		\
 if (!RATIONALP (x))				\
   x = wrong_type_argument (Qrationalp, x);	\
}  while (0)

EXFUN (Frationalp, 1);
EXFUN (Fnumerator, 1);
EXFUN (Fdenominator, 1);


/******************************** Bigfloats *********************************/
#ifdef HAVE_BIGFLOAT
struct Lisp_Bigfloat
{
  FROB_BLOCK_LISP_OBJECT_HEADER lheader;
  bigfloat bf;
};
typedef struct Lisp_Bigfloat Lisp_Bigfloat;

DECLARE_LISP_OBJECT (bigfloat, Lisp_Bigfloat);
#define XBIGFLOAT(x) XRECORD (x, bigfloat, Lisp_Bigfloat)
#define wrap_bigfloat(p) wrap_record (p, bigfloat)
#define BIGFLOATP(x) RECORDP (x, bigfloat)
#define CHECK_BIGFLOAT(x) CHECK_RECORD (x, bigfloat)
#define CONCHECK_BIGFLOAT(x) CONCHECK_RECORD (x, bigfloat)

#define bigfloat_data(f) ((f)->bf)
#define XBIGFLOAT_DATA(x) bigfloat_data (XBIGFLOAT (x))
#define XBIGFLOAT_GET_PREC(x) bigfloat_get_prec (XBIGFLOAT_DATA (x))
#define XBIGFLOAT_SET_PREC(x,p) bigfloat_set_prec (XBIGFLOAT_DATA (x), p)

#define BIGFLOAT_ARITH_RETURN(f,op) do					\
{									\
  Lisp_Object retval = make_bigfloat (0.0, bigfloat_get_default_prec()); \
  bigfloat_##op (XBIGFLOAT_DATA (retval), XBIGFLOAT_DATA (f));	\
  return retval;						\
} while (0)

#define BIGFLOAT_ARITH_RETURN1(f,op,arg) do				\
{									\
  Lisp_Object retval = make_bigfloat (0.0, bigfloat_get_default_prec()); \
  bigfloat_##op (XBIGFLOAT_DATA (retval), XBIGFLOAT_DATA (f), arg);	\
  return retval;							\
} while (0)

extern Lisp_Object make_bigfloat (double, unsigned long);
extern Lisp_Object make_bigfloat_bf (bigfloat);
extern Lisp_Object Vdefault_float_precision;
extern bigfloat scratch_bigfloat, scratch_bigfloat2;

#else /* !HAVE_BIGFLOAT */

#define BIGFLOATP(x)         0
#define CHECK_BIGFLOAT(x)    dead_wrong_type_argument (Qbigfloatp, x)
#define CONCHECK_BIGFLOAT(x) dead_wrong_type_argument (Qbigfloatp, x)
typedef void bigfloat;
#define make_bigfloat(f)     This XEmacs does not support bigfloats
#define make_bigfloat_bf(f)  This XEmacs does not support bigfloast

#endif /* HAVE_BIGFLOAT */

extern Lisp_Object Qbigfloatp;
EXFUN (Fbigfloatp, 1);

/********************************* Floating *********************************/
extern Lisp_Object Qfloatingp;
extern Lisp_Object Qread_default_float_format, Vread_default_float_format;

#define FLOATINGP(x) (FLOATP (x) || BIGFLOATP (x))
#define CHECK_FLOATING(x) do {			\
 if (!FLOATINGP (x))				\
   dead_wrong_type_argument (Qfloatingp, x);	\
 } while (0)
#define CONCHECK_FLOATING(x) do {		\
 if (!FLOATINGP (x))				\
   x = wrong_type_argument (Qfloating, x);	\
}  while (0)

extern Lisp_Object make_floating (double);
EXFUN (Ffloatp, 1);


/********************************** Reals ***********************************/
extern Lisp_Object Qrealp;

#define REALP(x) (RATIONALP (x) || FLOATINGP (x))
#define CHECK_REAL(x) do {			\
 if (!REALP (x))				\
   dead_wrong_type_argument (Qrealp, x);	\
 } while (0)
#define CONCHECK_REAL(x) do {			\
 if (!REALP (x))				\
   x = wrong_type_argument (Qrealp, x);		\
}  while (0)

EXFUN (Frealp, 1);


/********************************* Numbers **********************************/
/* Qnumberp in lisp.h */
#define NUMBERP(x) REALP (x)
#define CHECK_NUMBER(x) do {			\
  if (!NUMBERP (x))				\
    dead_wrong_type_argument (Qnumberp, x);	\
} while (0)
#define CONCHECK_NUMBER(x) do {			\
  if (!NUMBERP (x))				\
    x = wrong_type_argument (Qnumberp, x);	\
} while (0)

EXFUN (Fcanonicalize_number, 1);

#define NUMBER_TYPES(prefix) prefix##FIXNUM_T, prefix##BIGNUM_T, \
    prefix##RATIO_T, prefix##FLOAT_T, prefix##BIGFLOAT_T

#ifdef _MSC_VER
/* Disable warning 4003:
 * warning C4003: not enough actual parameters for macro 'NUMBER_TYPES'
 */
#pragma warning( push )
#pragma warning( disable : 4003)
#endif

enum number_type { NUMBER_TYPES() };
enum lazy_number_type { NUMBER_TYPES(LAZY_), LAZY_MARKER_T };

#ifdef _MSC_VER
#pragma warning( pop )
#endif

#undef NUMBER_TYPES

extern enum number_type get_number_type (Lisp_Object);
extern enum number_type promote_args (Lisp_Object *, Lisp_Object *);

#ifdef WITH_NUMBER_TYPES

/* promote_args() *always* converts a marker argument to a fixnum.

   Unfortunately, for a marker with byte position N, getting the (character)
   marker position is O(N). Getting the character position isn't necessary
   for bytecode_arithcompare() if two markers being compared are in the same
   buffer, comparing the byte position is enough.

   Similarly, min and max don't necessarily need to have their arguments
   converted from markers, though we have always promised up to this point
   that the result is a fixnum rather than a marker, and that's what we're
   continuing to do. */

DECLARE_INLINE_HEADER (
enum lazy_number_type
promote_args_lazy (Lisp_Object *obj1, Lisp_Object *obj2))
{
  if (MARKERP (*obj1) && MARKERP (*obj2) &&
      XMARKER (*obj1)->buffer == XMARKER (*obj2)->buffer)
    {
      return LAZY_MARKER_T;
    }

  return (enum lazy_number_type) promote_args (obj1, obj2);
}

DECLARE_INLINE_HEADER (
int
non_fixnum_number_p (Lisp_Object object))
{
  if (LRECORDP (object))
    {
      switch (XRECORD_LHEADER (object)->type)
	{
	case lrecord_type_float:
#ifdef HAVE_BIGNUM
	case lrecord_type_bignum:
#endif
#ifdef HAVE_RATIO
	case lrecord_type_ratio:
#endif
#ifdef HAVE_BIGFLOAT
	case lrecord_type_bigfloat:
#endif
	  return 1;
	}
    }
  return 0;
}
#define NON_FIXNUM_NUMBER_P(X) non_fixnum_number_p (X)

#else
#define NON_FIXNUM_NUMBER_P FLOATP
#endif


#endif /* INCLUDED_number_h_ */
