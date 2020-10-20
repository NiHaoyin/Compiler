 /*
  *  The scanner definition for seal.
  */

 /*
  *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
  *  output, so headers and global definitions are placed here to be visible
  * to the code in the file.  Don't remove anything that was here initially
  */
%{

#include <seal-parse.h>
#include <stringtab.h>
#include <utilities.h>
#include <stdint.h>
#include <stdlib.h>
#include <string>
#include <cstring>
#include <assert.h>

/* The compiler assumes these identifiers. */
#define yylval seal_yylval
#define yylex  seal_yylex

/* Max size of string constants */
#define MAX_STR_CONST 256
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the seal compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE seal_yylval;

/*
 *  Add Your own definitions here
 */

// handle comments
int comment_layer = 0;

// handle '{' and '}'
int brace_num = 0;

// handle hex
char* hex2dec (char* hex){
  int num;
  char* res = new char[MAX_STR_CONST];
  num = std::stoi(hex, nullptr, 16);
  sprintf(res, "%d", num);
  return res;
}
// handle string
char* getstr (const char* str) {
  char *result;
  int i = 1, j = 0;
  int len = strlen(str);
  result = new char[MAX_STR_CONST];

  while (i < len - 1) {
    if (i < len-2 && str[i] == '\\') {
      if (str[i+1] == '\n') {
        result[j] = '\n';
        i += 2; 
      } else if (str[i+1] == '\\') {
        result[j] = '\\';
        i += 2;
      } else if (str[i+1] == '0') {
        result[j] = '\\';
        i += 1;
      } else {
        i++;
        while (i<len && str[i] != '\\') i++;
        i ++;
        j --;
      }
    } else {
      result[j] = str[i];
      i ++;
    }
    j ++;
  }
  result[j] = '\0';

  return result;
}


%}

%option noyywrap
%s COMMENTS
 /* STRING1 handle '"' STRING2 handle '`' */
%s STRING1 
%s STRING2 

 /*
  * Define names for regular expressions here.
  */

%%

 /* Rules */
<INITIAL>var {return VAR;}
<INITIAL>[ ] {}
<INITIAL>[;] {return (';');}
<INITIAL>[=] {return ('=');}
<INITIAL>[\n] {curr_lineno++;}
<INITIAL>if {return IF;}
<INITIAL>while {return WHILE;}
<INITIAL>func {return FUNC;}
<INITIAL>return {return RETURN;}
<INITIAL>break {return BREAK;}
<INITIAL>continue {return CONTINUE;}
<INITIAL>[+] {return ('+');}
<INITIAL>[-] {return ('-');}
<INITIAL>[*] {return ('*');}
<INITIAL>[/] {return ('/');}
<INITIAL>[>] {return ('>');}
<INITIAL>[<] {return ('<');}
<INITIAL>[%] {return ('%');}
<INITIAL>">=" {return GE;}
<INITIAL>"<=" {return LE;}
<INITIAL>"==" {return EQUAL;}
<INITIAL>[,] {return (',');}
<INITIAL>\t {}
<INITIAL>true {seal_yylval.boolean=1;return CONST_BOOL;}
<INITIAL>false {seal_yylval.boolean=0;return CONST_BOOL;}
<INITIAL>[|] {return ('|');}
<INITIAL>[\(] {return ('(');}
<INITIAL>[\)] {return (')');}
<INITIAL>[{] {return ('{'); }
<INITIAL>[}] {return ('}');}

 /* String1 */
<INITIAL>["] {
  BEGIN STRING1;
  yymore();
}
 /* MEET space*/
<STRING1>[ ] {
  yymore();
}
 /* Meet '\\0'*/
<STRING1>\\\\0 {yymore();}
 /* Meet '\0'*/
<STRING1>\\0 {strcpy(seal_yylval.error_msg, yytext); ;return ERROR;}
 /* MEET '\n'*/
<STRING1>[\n] {
  curr_lineno++;
  yymore();
}
 /*When the string ends, we need to modify it */
<STRING1>["] {
  std::string input(yytext, yyleng);
  
  // input = input.substr(1, input.length()-2);
  
  if (yyleng > 256){
    BEGIN INITIAL;
    return ERROR;
  }
  seal_yylval.symbol = stringtable.add_string(getstr(input.c_str()));
  BEGIN INITIAL;
  return CONST_STRING;
}
 /* Meet the words that do not include ' " \0 */
<STRING1>[^"`\0\n]+ {
  yymore();
}
 
 /* String2 */
<INITIAL>[`] {
  BEGIN STRING2;
  yymore();
}
 /* MEET space*/
<STRING2>[ ] {
  yymore();
}
 /* MEET '\n'*/
<STRING2>[\n] {
  curr_lineno++;
  yymore();
}
 /*When the string ends, we need to modify it */
<STRING2>[`] {
  std::string input(yytext, yyleng);
  
  input = input.substr(1, input.length()-2);

  if (yyleng > 256){
    BEGIN INITIAL;
    return ERROR;
  }
  seal_yylval.symbol = stringtable.add_string((char*)input.c_str());
  BEGIN INITIAL;
  return CONST_STRING;
}
<STRING2>[;] {return (';');}
 /* Meet the words that do not include ' " \0 */
<STRING2>[^"`\0\n]+ {
  yymore();
}

 /* Comments*/
<INITIAL>"/*" {
        comment_layer++;
        BEGIN COMMENTS;
        }
<COMMENTS>"*/" {
        comment_layer--;
        if (comment_layer == 0){
          BEGIN INITIAL;
        }
        }
<COMMENTS>. {}
<COMMENTS>[\n] {curr_lineno++;}
<COMMENTS>[ ] {}
 /*OBJECTID and TYPEID */
<INITIAL>(Int|Float|Bool|String) {
    seal_yylval.symbol = idtable.add_string(yytext);
    return TYPEID;
}
<INITIAL>[a-z_][a-zA-Z0-9]* {
    seal_yylval.symbol = idtable.add_string(yytext);
    return OBJECTID;
}
  
 /* CONST_INT */
<INITIAL>0|[1-9][0-9]*  {
   seal_yylval.symbol = inttable.add_string(yytext);
   return CONST_INT;
 }
  /* CONST_FLOAT */
<INITIAL>(0|[1-9][0-9]*)[.][0-9]+ {
   seal_yylval.symbol = floattable.add_string(yytext);
   return CONST_FLOAT;
}

 /* handle hex*/
<INITIAL>0x[a-zA-Z0-9]+ {
   seal_yylval.symbol = inttable.add_string(hex2dec(yytext));
   return CONST_INT;
}

.	{
	strcpy(seal_yylval.error_msg, yytext); 
	return (ERROR); 
}

%%
