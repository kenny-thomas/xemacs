/* Definitions for data structures and routines for the regular
   expression library, version 0.12.

   Copyright (C) 1985, 89, 90, 91, 92, 93, 95 Free Software Foundation, Inc.
   Copyright (C) 2002, 2010 Ben Wing.

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
/* Synched up with: FSF 19.29. */

#ifndef INCLUDED_regex_h_
#define INCLUDED_regex_h_

#ifdef emacs
#define RE_TRANSLATE_TYPE Lisp_Object
#define RE_LISP_SHORT_CONTEXT_ARGS_DECL , Lisp_Object UNUSED (lispobj), struct buffer *UNUSED (lispbuf)
#define RE_LISP_SHORT_CONTEXT_ARGS , lispobj, lispbuf
#define RE_LISP_CONTEXT_ARGS_DECL , Lisp_Object lispobj, struct buffer *lispbuf, struct syntax_cache *scache
#define RE_LISP_CONTEXT_ARGS_MULE_DECL , Lisp_Object lispobj, struct buffer *USED_IF_MULE (lispbuf), struct syntax_cache *scache
#define RE_LISP_CONTEXT_ARGS , lispobj, lispbuf, scache
#define RE_ISWCTYPE_ARG_DECL , struct buffer *lispbuf
#define RE_ISWCTYPE_ARG(varname) , varname
#else
#define RE_TRANSLATE_TYPE char *
#define RE_LISP_SHORT_CONTEXT_ARGS_DECL
#define RE_LISP_SHORT_CONTEXT_ARGS
#define RE_LISP_CONTEXT_ARGS_DECL
#define RE_LISP_CONTEXT_ARGS_MULE_DECL
#define RE_LISP_CONTEXT_ARGS
#define RE_ISWCTYPE_ARG_DECL 
#define RE_ISWCTYPE_ARG(varname)
#define Elemcount ssize_t
#define Bytecount ssize_t
#endif /* emacs */

#ifndef emacs
# ifdef __cplusplus
#  define BEGIN_C_DECLS extern "C" {
#  define END_C_DECLS }
# else
#  define BEGIN_C_DECLS
#  define END_C_DECLS
# endif
#endif /* emacs */

BEGIN_C_DECLS

/* POSIX says that <sys/types.h> must be included (by the caller) before
   <regex.h>.  */


/* The following bits are used to determine the regexp syntax we
   recognize.  The not-set meaning typically corresponds to the syntax
   used by Emacs (the exception is RE_INTERVAL, made for historical
   reasons).  The bits are given in alphabetical order, and the
   definitions shifted by one from the previous bit; thus, when we add or
   remove a bit, only one other definition need change.  */
typedef unsigned reg_syntax_t;

/* If this bit is not set, then \ inside a bracket expression is literal.
   If set, then such a \ quotes the following character.  */
#define RE_BACKSLASH_ESCAPE_IN_LISTS (1)

/* If this bit is not set, then + and ? are operators, and \+ and \? are
     literals.
   If set, then \+ and \? are operators and + and ? are literals.  */
#define RE_BK_PLUS_QM (RE_BACKSLASH_ESCAPE_IN_LISTS << 1)

/* If this bit is set, then character classes are supported.  They are:
     [:alpha:], [:upper:], [:lower:],  [:digit:], [:alnum:], [:xdigit:],
     [:space:], [:print:], [:punct:], [:graph:], and [:cntrl:].
   If not set, then character classes are not supported.  */
#define RE_CHAR_CLASSES (RE_BK_PLUS_QM << 1)

/* If this bit is set, then ^ and $ are always anchors (outside bracket
     expressions, of course).
   If this bit is not set, then it depends:
        ^  is an anchor if it is at the beginning of a regular
           expression or after an open-group or an alternation operator;
        $  is an anchor if it is at the end of a regular expression, or
           before a close-group or an alternation operator.

   This bit could be (re)combined with RE_CONTEXT_INDEP_OPS, because
   POSIX draft 11.2 says that * etc. in leading positions is undefined.
   We already implemented a previous draft which made those constructs
   invalid, though, so we haven't changed the code back.  */
#define RE_CONTEXT_INDEP_ANCHORS (RE_CHAR_CLASSES << 1)

/* If this bit is set, then special characters are always special
     regardless of where they are in the pattern.
   If this bit is not set, then special characters are special only in
     some contexts; otherwise they are ordinary.  Specifically,
     * + ? and intervals are only special when not after the beginning,
     open-group, or alternation operator.  */
#define RE_CONTEXT_INDEP_OPS (RE_CONTEXT_INDEP_ANCHORS << 1)

/* If this bit is set, then *, +, ?, and { cannot be first in an re or
     immediately after an alternation or begin-group operator.  */
#define RE_CONTEXT_INVALID_OPS (RE_CONTEXT_INDEP_OPS << 1)

/* If this bit is set, then . matches newline.
   If not set, then it doesn't.  */
#define RE_DOT_NEWLINE (RE_CONTEXT_INVALID_OPS << 1)

/* If this bit is set, then . doesn't match NUL.
   If not set, then it does.  */
#define RE_DOT_NOT_NULL (RE_DOT_NEWLINE << 1)

/* If this bit is set, nonmatching lists [^...] do not match newline.
   If not set, they do.  */
#define RE_HAT_LISTS_NOT_NEWLINE (RE_DOT_NOT_NULL << 1)

/* If this bit is set, either \{...\} or {...} defines an
     interval, depending on RE_NO_BK_BRACES.
   If not set, \{, \}, {, and } are literals.  */
#define RE_INTERVALS (RE_HAT_LISTS_NOT_NEWLINE << 1)

/* If this bit is set, +, ? and | aren't recognized as operators.
   If not set, they are.  */
#define RE_LIMITED_OPS (RE_INTERVALS << 1)

/* If this bit is set, newline is an alternation operator.
   If not set, newline is literal.  */
#define RE_NEWLINE_ALT (RE_LIMITED_OPS << 1)

/* If this bit is set, then `{...}' defines an interval, and \{ and \}
     are literals.
  If not set, then `\{...\}' defines an interval.  */
#define RE_NO_BK_BRACES (RE_NEWLINE_ALT << 1)

/* If this bit is set, (...) defines a group, and \( and \) are literals.
   If not set, \(...\) defines a group, and ( and ) are literals.  */
#define RE_NO_BK_PARENS (RE_NO_BK_BRACES << 1)

/* If this bit is set, then \<digit> matches <digit>.
   If not set, then \<digit> is a back-reference.  */
#define RE_NO_BK_REFS (RE_NO_BK_PARENS << 1)

/* If this bit is set, then | is an alternation operator, and \| is literal.
   If not set, then \| is an alternation operator, and | is literal.  */
#define RE_NO_BK_VBAR (RE_NO_BK_REFS << 1)

/* If this bit is set, then an ending range point collating higher
     than the starting range point, as in [z-a], is invalid.
   If not set, then when ending range point collates higher than the
     starting range point, the range is ignored.  */
#define RE_NO_EMPTY_RANGES (RE_NO_BK_VBAR << 1)

/* If this bit is not set, allow minimal matching:
    - a*? and a+? and a?? perform shortest-possible matching (compare with a*
      and a+ and a?, respectively, which perform longest-possible matching)
    - other juxtaposing of * + and ? is rejected.
   If this bit is set, consecutive * + and ?'s are collapsed in a logical
   manner:
    - a*? and a+? are the same as a*
    - a?? is the same as a?
 */
#define RE_NO_MINIMAL_MATCHING (RE_NO_EMPTY_RANGES << 1)

/* If this bit is set, succeed as soon as we match the whole pattern,
   without further backtracking.  */
#define RE_NO_POSIX_BACKTRACKING (RE_NO_MINIMAL_MATCHING << 1)

/* If this bit is not set, (?:re) behaves like (re) (or \(?:re\) behaves like
   \(re\)) except that the matched string is not registered.  */
#define RE_NO_SHY_GROUPS (RE_NO_POSIX_BACKTRACKING << 1)

/* If this bit is set, then an unmatched ) is ordinary.
   If not set, then an unmatched ) is invalid.  */
#define RE_UNMATCHED_RIGHT_PAREN_ORD (RE_NO_SHY_GROUPS << 1)

/* If this bit is set, then \22 will read as a back reference,
   provided at least 22 non-shy groups have been seen so far.  In all
   other cases (bit not set, not 22 non-shy groups seen so far), it
   reads as a back reference \2 followed by a digit 2. */
#define RE_NO_MULTI_DIGIT_BK_REFS (RE_UNMATCHED_RIGHT_PAREN_ORD << 1)

/* This global variable defines the particular regexp syntax to use (for
   some interfaces).  When a regexp is compiled, the syntax used is
   stored in the pattern buffer, so changing this does not affect
   already-compiled regexps.  */
extern reg_syntax_t re_syntax_options;

/* Define combinations of the above bits for the standard possibilities.
   (The [[[ comments delimit what gets put into the Texinfo file, so
   don't delete them!)  */
/* [[[begin syntaxes]]] */
#define RE_SYNTAX_EMACS (RE_INTERVALS | RE_CHAR_CLASSES)

#define RE_SYNTAX_AWK							\
  (RE_BACKSLASH_ESCAPE_IN_LISTS | RE_DOT_NOT_NULL			\
   | RE_NO_BK_PARENS            | RE_NO_BK_REFS				\
   | RE_NO_BK_VBAR               | RE_NO_EMPTY_RANGES			\
   | RE_UNMATCHED_RIGHT_PAREN_ORD | RE_NO_SHY_GROUPS			\
   | RE_NO_MINIMAL_MATCHING | RE_NO_MULTI_DIGIT_BK_REFS)

#define RE_SYNTAX_POSIX_AWK 						\
  (RE_SYNTAX_POSIX_EXTENDED | RE_BACKSLASH_ESCAPE_IN_LISTS)

#define RE_SYNTAX_GREP							\
  (RE_BK_PLUS_QM              | RE_CHAR_CLASSES				\
   | RE_HAT_LISTS_NOT_NEWLINE | RE_INTERVALS				\
   | RE_NEWLINE_ALT           | RE_NO_SHY_GROUPS			\
   | RE_NO_MINIMAL_MATCHING | RE_NO_MULTI_DIGIT_BK_REFS)

#define RE_SYNTAX_EGREP							\
  (RE_CHAR_CLASSES        | RE_CONTEXT_INDEP_ANCHORS			\
   | RE_CONTEXT_INDEP_OPS | RE_HAT_LISTS_NOT_NEWLINE			\
   | RE_NEWLINE_ALT       | RE_NO_BK_PARENS				\
   | RE_NO_BK_VBAR        | RE_NO_SHY_GROUPS				\
   | RE_NO_MINIMAL_MATCHING | RE_NO_MULTI_DIGIT_BK_REFS)

#define RE_SYNTAX_POSIX_EGREP						\
  (RE_SYNTAX_EGREP | RE_INTERVALS | RE_NO_BK_BRACES |			\
   RE_NO_MULTI_DIGIT_BK_REFS)

/* P1003.2/D11.2, section 4.20.7.1, lines 5078ff.  */
#define RE_SYNTAX_ED RE_SYNTAX_POSIX_BASIC

#define RE_SYNTAX_SED RE_SYNTAX_POSIX_BASIC

/* Syntax bits common to both basic and extended POSIX regex syntax.  */
#define _RE_SYNTAX_POSIX_COMMON						\
  (RE_CHAR_CLASSES | RE_DOT_NEWLINE      | RE_DOT_NOT_NULL		\
   | RE_INTERVALS  | RE_NO_EMPTY_RANGES | RE_NO_SHY_GROUPS		\
   | RE_NO_MINIMAL_MATCHING | RE_NO_MULTI_DIGIT_BK_REFS)

#define RE_SYNTAX_POSIX_BASIC						\
  (_RE_SYNTAX_POSIX_COMMON | RE_BK_PLUS_QM)

/* Differs from ..._POSIX_BASIC only in that RE_BK_PLUS_QM becomes
   RE_LIMITED_OPS, i.e., \? \+ \| are not recognized.  Actually, this
   isn't minimal, since other operators, such as \`, aren't disabled.  */
#define RE_SYNTAX_POSIX_MINIMAL_BASIC					\
  (_RE_SYNTAX_POSIX_COMMON | RE_LIMITED_OPS)

#define RE_SYNTAX_POSIX_EXTENDED					\
  (_RE_SYNTAX_POSIX_COMMON | RE_CONTEXT_INDEP_ANCHORS			\
   | RE_CONTEXT_INDEP_OPS  | RE_NO_BK_BRACES				\
   | RE_NO_BK_PARENS       | RE_NO_BK_VBAR				\
   | RE_UNMATCHED_RIGHT_PAREN_ORD)

/* Differs from ..._POSIX_EXTENDED in that RE_CONTEXT_INVALID_OPS
   replaces RE_CONTEXT_INDEP_OPS and RE_NO_BK_REFS is added.  */
#define RE_SYNTAX_POSIX_MINIMAL_EXTENDED				\
  (_RE_SYNTAX_POSIX_COMMON  | RE_CONTEXT_INDEP_ANCHORS			\
   | RE_CONTEXT_INVALID_OPS | RE_NO_BK_BRACES				\
   | RE_NO_BK_PARENS        | RE_NO_BK_REFS				\
   | RE_NO_BK_VBAR	    | RE_UNMATCHED_RIGHT_PAREN_ORD)
/* [[[end syntaxes]]] */

/* Maximum number of duplicates an interval can allow.  Some systems
   (erroneously) define this in other header files, but we want our
   value, so remove any previous define.  */
#ifdef RE_DUP_MAX
#undef RE_DUP_MAX
#endif
#define RE_DUP_MAX ((1 << 15) - 1)


/* POSIX `cflags' bits (i.e., information for `regcomp').  */

/* If this bit is set, then use extended regular expression syntax.
   If not set, then use basic regular expression syntax.  */
#define REG_EXTENDED 1

/* If this bit is set, then ignore case when matching.
   If not set, then case is significant.  */
#define REG_ICASE (REG_EXTENDED << 1)

/* If this bit is set, then anchors do not match at newline
     characters in the string.
   If not set, then anchors do match at newlines.  */
#define REG_NEWLINE (REG_ICASE << 1)

/* If this bit is set, then report only success or fail in regexec.
   If not set, then returns differ between not matching and errors.  */
#define REG_NOSUB (REG_NEWLINE << 1)


/* POSIX `eflags' bits (i.e., information for regexec).  */

/* If this bit is set, then the beginning-of-line operator doesn't match
     the beginning of the string (presumably because it's not the
     beginning of a line).
   If not set, then the beginning-of-line operator does match the
     beginning of the string.  */
#define REG_NOTBOL 1

/* Like REG_NOTBOL, except for the end-of-line.  */
#define REG_NOTEOL (1 << 1)


/* If any error codes are removed, changed, or added, update the
   `re_error_msg' table in regex.c.  */
typedef enum
{
  REG_NOERROR = 0,	/* Success.  */
  REG_NOMATCH,		/* Didn't find a match (for regexec).  */

  /* POSIX regcomp return error codes.  (In the order listed in the
     standard.)  */
  REG_BADPAT,		/* Invalid pattern.  */
  REG_ECOLLATE,		/* Not implemented.  */
  REG_ECTYPE,		/* Invalid character class name.  */
  REG_EESCAPE,		/* Trailing backslash.  */
  REG_ESUBREG,		/* Invalid back reference.  */
  REG_EBRACK,		/* Unmatched left bracket.  */
  REG_EPAREN,		/* Parenthesis imbalance.  */
  REG_EBRACE,		/* Unmatched \{.  */
  REG_BADBR,		/* Invalid contents of \{\}.  */
  REG_ERANGE,		/* Invalid range end.  */
  REG_ESPACE,		/* Ran out of memory.  */
  REG_BADRPT,		/* No preceding re for repetition op.  */

  /* Error codes we've added.  */
  REG_EEND,		/* Premature end.  */
  REG_ESIZE,		/* Compiled pattern bigger than 2^16 bytes.  */
  REG_ERPAREN		/* Unmatched ) or \); not returned from regcomp.  */
#ifdef emacs
  ,REG_ESYNTAX		/* Invalid syntax designator. */
#endif
#ifdef MULE
  ,REG_ERANGESPAN	/* Ranges may not span charsets. */
  ,REG_ECATEGORY	/* Invalid category designator */
#endif
} reg_errcode_t;

/* This data structure represents a compiled pattern.  Before calling
   the pattern compiler, the fields `buffer', `allocated', `fastmap',
   `translate', and `no_sub' can be set.  After the pattern has been
   compiled, the `re_nsub' field is available.  All other fields are
   private to the regex routines.  */

struct re_pattern_buffer
{
/* [[[begin pattern_buffer]]] */
	/* Space that holds the compiled pattern.  It is declared as
          `unsigned char *' because its elements are
           sometimes used as array indexes.  */
  unsigned char *buffer;

	/* Number of bytes to which `buffer' points.  */
  long allocated;

	/* Number of bytes actually used in `buffer'.  */
  long used;

        /* Syntax setting with which the pattern was compiled.  */
  reg_syntax_t syntax;

        /* Pointer to a fastmap, if any, otherwise zero.  re_search uses
           the fastmap, if there is one, to skip over impossible
           starting points for matches.  */
  char *fastmap;

        /* Either a translate table to apply to all characters before
           comparing them, or zero for no translation.  The translation
           is applied to a pattern when it is compiled and to a string
           when it is matched.  */
  RE_TRANSLATE_TYPE translate;

	/* Number of subpatterns (returnable groups) found by the compiler.
	   (This does not count shy groups.) */
  int re_nsub;

	/* Total number of groups found by the compiler. (Including
	   shy ones.) */
  int re_ngroups;

        /* Zero if this pattern cannot match the empty string, one else.
           Well, in truth it's used only in `re_search_2', to see
           whether or not we should use the fastmap, so we don't set
           this absolutely perfectly; see `re_compile_fastmap' (the
           `duplicate' case).  */
  unsigned int can_be_null : 1;

        /* If REGS_UNALLOCATED, allocate space in the `regs' structure
             for `max (RE_NREGS, re_nsub + 1)' groups.
           If REGS_REALLOCATE, reallocate space if necessary.
           If REGS_FIXED, use what's there.  */
#define REGS_UNALLOCATED 0
#define REGS_REALLOCATE 1
#define REGS_FIXED 2
  unsigned int regs_allocated : 2;

        /* Set to zero when `regex_compile' compiles a pattern; set to one
           by `re_compile_fastmap' if it updates the fastmap.  */
  unsigned int fastmap_accurate : 1;

        /* If set, `re_match_2' does not return information about
           subexpressions.  */
  unsigned int no_sub : 1;

        /* If set, a beginning-of-line anchor doesn't match at the
           beginning of the string.  */
  unsigned int not_bol : 1;

        /* Similarly for an end-of-line anchor.  */
  unsigned int not_eol : 1;

        /* If true, an anchor at a newline matches.  */
  unsigned int newline_anchor : 1;

  unsigned int warned_about_incompatible_back_references : 1;

	/* Mapping between back references and groups (may not be
	   equivalent with shy groups). */
  int *external_to_internal_register;

  int external_to_internal_register_size;

/* [[[end pattern_buffer]]] */
};

typedef struct re_pattern_buffer regex_t;

/* Type for byte offsets within the string.  POSIX mandates this.  */
typedef int regoff_t;


/* This is the structure we store register match data in.  See
   regex.texinfo for a full description of what registers match.  */
struct re_registers
{
  int num_regs;			/* number of registers allocated */
  regoff_t *start;
  regoff_t *end;
};


/* If `regs_allocated' is REGS_UNALLOCATED in the pattern buffer,
   `re_match_2' returns information about at least this many registers
   the first time a `regs' structure is passed.  */
#ifndef RE_NREGS
#define RE_NREGS 30
#endif


/* POSIX specification for registers.  Aside from the different names than
   `re_registers', POSIX uses an array of structures, instead of a
   structure of arrays.  */
typedef struct
{
  regoff_t rm_so;  /* Byte offset from string's start to substring's start.  */
  regoff_t rm_eo;  /* Byte offset from string's start to substring's end.  */
} regmatch_t;

/* Declarations for routines.  */

/* Sets the current default syntax to SYNTAX, and return the old syntax.
   You can also simply assign to the `re_syntax_options' variable.  */
reg_syntax_t re_set_syntax (reg_syntax_t syntax);

/* Compile the regular expression PATTERN, with length LENGTH
   and syntax given by the global `re_syntax_options', into the buffer
   BUFFER.  Return NULL if successful, and an error string if not.  */
const char *re_compile_pattern (const char *pattern, int length,
				struct re_pattern_buffer *buffer);


/* Compile a fastmap for the compiled pattern in BUFFER; used to
   accelerate searches.  Return 0 if successful and -2 if was an
   internal error.  */
int re_compile_fastmap (struct re_pattern_buffer *buffer
			RE_LISP_SHORT_CONTEXT_ARGS_DECL);


/* Search in the string STRING (with length LENGTH) for the pattern
   compiled into BUFFER.  Start searching at position START, for RANGE
   characters.  Return the starting position of the match, -1 for no
   match, or -2 for an internal error.  Also return register
   information in REGS (if REGS and BUFFER->no_sub are nonzero).  */
int re_search (struct re_pattern_buffer *buffer, const char *string,
	       int length, int start, int range,
	       struct re_registers *regs RE_LISP_CONTEXT_ARGS_DECL);


/* Like `re_search', but search in the concatenation of STRING1 and
   STRING2.  Also, stop searching at index START + STOP.  */
int re_search_2 (struct re_pattern_buffer *buffer, const char *string1,
		 int length1, const char *string2, int length2, int start,
		 int range, struct re_registers *regs, int stop
		 RE_LISP_CONTEXT_ARGS_DECL);

#ifndef emacs /* never used by XEmacs */

/* Like `re_search', but return how many characters in STRING the regexp
   in BUFFER matched, starting at position START.  */
int re_match (struct re_pattern_buffer *buffer, const char *string,
	      int length, int start, struct re_registers *regs
	      RE_LISP_CONTEXT_ARGS_DECL);

#endif /* not emacs */

/* Relates to `re_match' as `re_search_2' relates to `re_search'.  */
int re_match_2 (struct re_pattern_buffer *buffer, const char *string1,
		int length1, const char *string2, int length2,
		int start, struct re_registers *regs, int stop
		RE_LISP_CONTEXT_ARGS_DECL);

/* Set REGS to hold NUM_REGS registers, storing them in STARTS and
   ENDS.  Subsequent matches using BUFFER and REGS will use this memory
   for recording register information.  STARTS and ENDS must be
   allocated with malloc, and must each be at least `NUM_REGS * sizeof
   (regoff_t)' bytes long.

   If NUM_REGS == 0, then subsequent matches should allocate their own
   register data.

   Unless this function is called, the first search or match using
   PATTERN_BUFFER will allocate its own register data, without
   freeing the old data.  */
void re_set_registers (struct re_pattern_buffer *buffer,
		       struct re_registers *regs, int num_regs,
		       regoff_t *starts, regoff_t *ends);

#ifdef _REGEX_RE_COMP
/* 4.2 bsd compatibility.  */
char *re_comp (const char *);
int re_exec (const char *);
#endif

/* POSIX compatibility.  */
int regcomp (regex_t *preg, const char *pattern, int cflags);
int regexec (const regex_t *preg, const char *string, size_t nmatch,
	     regmatch_t pmatch[], int eflags);
size_t regerror (int errcode, const regex_t *preg, char *errbuf,
		 size_t errbuf_size);
void regfree (regex_t *preg);

enum regex_debug
  {
    RE_DEBUG_COMPILATION = 1 << 0,
    RE_DEBUG_FAILURE_POINT = 1 << 1,
    RE_DEBUG_MATCHING = 1 << 2,
  };

extern int debug_regexps;

typedef enum
  {
    RECC_ERROR = 0,
    RECC_ALNUM, RECC_ALPHA, RECC_WORD,
    RECC_GRAPH, RECC_PRINT,
    RECC_LOWER, RECC_UPPER,
    RECC_PUNCT, RECC_CNTRL,
    RECC_DIGIT, RECC_XDIGIT,
    RECC_BLANK, RECC_SPACE,
    RECC_MULTIBYTE, RECC_NONASCII,
    RECC_ASCII, RECC_UNIBYTE
} re_wctype_t;

#define CHAR_CLASS_MAX_LENGTH  9 /* Namely, `multibyte'.  */

/* Map a string to the char class it names (if any).  */
re_wctype_t re_wctype (const char *);

/* Is character CH a member of the character class CC? */
int re_iswctype (int ch, re_wctype_t cc RE_ISWCTYPE_ARG_DECL);

/* Bits used to implement the multibyte-part of the various character
   classes such as [:alnum:] in a charset's range table. XEmacs; use an
   enum, so they're visible in the debugger. */
enum
{
  BIT_WORD = (1 << 0),
  BIT_LOWER = (1 << 1),
  BIT_PUNCT = (1 << 2),
  BIT_SPACE = (1 << 3),
  BIT_UPPER = (1 << 4),
  /* XEmacs; we need this, because we unify treatment of ASCII and non-ASCII
     (possible matches) in charset_mule. [:alpha:] matches all characters
     with word syntax, with the exception of [0-9]. We don't need
     BIT_MULTIBYTE. */
  BIT_ALPHA = (1 << 5)
};

#ifdef emacs
reg_errcode_t compile_char_class (re_wctype_t cc, Lisp_Object rtab,
                                  Bitbyte *flags_out);

#endif

/* isalpha etc. are used for the character classes.  */
#include <ctype.h>

#ifdef emacs

/* 1 if C is an ASCII character.  */
#define ISASCII(c) ((c) < 0x80)

/* 1 if C is a unibyte character.  */
#define ISUNIBYTE ISASCII

/* The Emacs definitions should not be directly affected by locales.  */

/* In Emacs, these are only used for single-byte characters.  */
#define ISDIGIT(c) ((c) >= '0' && (c) <= '9')
#define ISCNTRL(c) ((c) < ' ')
#define ISXDIGIT(c) (ISDIGIT (c) || ((c) >= 'a' && (c) <= 'f')	\
		     || ((c) >= 'A' && (c) <= 'F'))

/* This is only used for single-byte characters.  */
#define ISBLANK(c) ((c) == ' ' || (c) == '\t')

/* The rest must handle multibyte characters.  */

#define ISGRAPH(c) ((c) > ' ' && (c) != 0x7f)
#define ISPRINT(c) ((c) == ' ' || ISGRAPH (c))
#define ISALPHA(c) (ISASCII (c) ? (((c) >= 'a' && (c) <= 'z')		\
				   || ((c) >= 'A' && (c) <= 'Z'))	\
		    : ISWORD (c))
#define ISALNUM(c) (ISALPHA (c) || ISDIGIT (c))

#define ISLOWER(c) LOWERCASEP (lispbuf, c)

#define ISPUNCT(c) (ISASCII (c)                                 \
		    ? ((c) > ' ' && (c) < 0x7F			\
		       && !(((c) >= 'a' && (c) <= 'z')		\
		            || ((c) >= 'A' && (c) <= 'Z')	\
		            || ((c) >= '0' && (c) <= '9')))	\
		    : !ISWORD (c))

#define ISSPACE(c) \
	(SYNTAX (BUFFER_MIRROR_SYNTAX_TABLE (lispbuf), c) == Swhitespace)

#define ISUPPER(c) UPPERCASEP (lispbuf, c)

#define ISWORD(c) (SYNTAX (BUFFER_MIRROR_SYNTAX_TABLE (lispbuf), c) == Sword)

#endif 

END_C_DECLS

#endif /* INCLUDED_regex_h_ */
