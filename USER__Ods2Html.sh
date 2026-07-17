#!/bin/bash

###
####################################################################################################
###

echo="echo -e"
dbg=0
mode=0
inFile=""
outFile=""
outPref=""

while [ $# -gt 0 ]
do
	case "${1}" in
		"--ods" ) inFile="${2}" ; mode=1 ; shift ; shift ;;
		"--out" ) outFile="${2}" ; shift ; shift ;;
		"--prefix" ) outPref="${2}" ; shift ; shift ;;
		"--debug" ) dbg=1 ; shift ;;
		* ) ${echo} "\n\t Invalid parameter used on command line.  Valid options:  --ods {ods_file}  --out {out_html} \n" ; exit 1 ;;
	esac
done

if [  -z "${inFile}" ]
then
	${echo} "\n\t Filename of ODS spreadsheet required using:  --ods {ods_file}.  Unable to proceed.\n" ; exit 1
fi

echo "${inFile##*.}"

suffix=$( ${echo} "${inFile##*.}" | tr '[:upper:]' '[:lower:]' )
test ${dbg} -eq 1 && ${echo} "suffix = ${suffix}"

if [ ${mode} -eq 1 ]
then
	if [ "${suffix}" = "ods" ]
	then
		#inBase=$( basename "${inFile}" ".${suffix}" )
		baseFile="${inFile##*/}"
		test ${dbg} -eq 1 && ${echo} "baseFile = ${baseFile}"
		inBase="${inFile%.*}"
		test ${dbg} -eq 1 && ${echo} "inBase = ${inBase}"

		outFile="${inBase}.html"
	else
		${echo} "\n\t Filetype suffix does not match specified *.ods format.  Unable to proceed.\n" ; exit 1
	fi
fi

if [  ! -s "${inFile}" ]
then
	${echo} "\n\t Unable to locate file '${inFile}'.  Unable to proceed with Phase 1.\n" ; exit 1
fi

if [  -z "${outFile}" ]
then
	${echo} "\n\t Filename of generated HTML file required using:  --out {out_file}.  Unable to proceed.\n" ; exit 1
fi

if [  -z "${outPref}" ]
then
	${echo} "\n\t The shared prefix for the exploded HTML file is required using:  --prefix {out_pref}. Unable to proceed.\n" ; exit 1
fi


###
####################################################################################################
###

phase_01()
{

###
###	Export LibreOffice spreadsheet as monolithic HTML page with URL tag at start of each logical Tab/Sheet
###

#pandoc "${inFile}" -f odt -t html5 -s -o "${outFile}"
#pandoc "${inFile}" -f ods -t html5 -s -o "${outFile}"

libreoffice --headless --convert-to html "${inFile}"

echo ""
ls -l "${outFile}"
#ls -l *.html
}


###
####################################################################################################
###

phase_02()
{

###
###	Explode monolithic HTML file into distinct files for each sheet.
###

if [ ! -s "${outFile}" ]
then
	${echo} "/n/t Expected HTML file '${outFile}' is missing.  Unable to proceed with Phase 2.\n" ; exit 1
fi


echo ""
cat "${outFile}" | awk -v mono="${outFile}" -v pref="${outPref}" 'BEGIN{
	cond1=0 ;			# Boolean - detected start of index list
	cond2=0 ;
	split("", sheetNames) ;		# Array   - names assigned by LibreOffice
	split("", sheetLabels) ;	# Array   - labels assigned by LibreOffice
	indxS=0 ;
	indx=0 ;			# Boolean - all sheet names captured = 1
	sheets=0 ;			# Boolean - all sheet start and end lines captured = 1

}

function openHTML(){
	h1="<!DOCTYPE html>\n<html lang=\"en-CA\" >\n<head>\n\t<!-- CALL_FUNCTION_OPEN_HTML -->\n\t<title>" ;
	h2="</title>\n\t<!-- Sheet Start Line = " ;
	h3="; Sheet End Line = " ;
	h4=" -->\n</head>\n<body>\n" ;
	printf("%s %s %s %d %s %d %s\n", \
		h1, sheetLabels[i], \
		h2, sheetStart[i], \
		h3, sheetEnd[i], \
		h4 ) >outfile ;
}

function closeHTML(){
	b1="\n<!-- CALL_FUNCTION_CLOSE_HTML -->\n</body>\n</html>\n" ;
	printf("%s\n", b1 ) >>outfile ;
}

{
	if( indx == 1 ){
		if( $0 ~ sheetNames[lookMatch] ){
			sheetStart[lookMatch]=NR ;
			if( cond2 == 0 ){
				printf("\t DEBUG |sheetNames  NR = %d\n", NR ) | "cat 1>&2" ;
			} ;
			if( lookMatch != 1 ){
				sheetEnd[lookMatch-1]=NR-1 ;
			} ;
			if( lookMatch == indxS ){
				cond2=1 ;
			} ;
			if( cond2 == 0 ){
				lookMatch++ ;
			} ;
		}else{
			if( $0 ~ /<[/]body>/ ){
				sheetEnd[lookMatch]=NR-1 ;
				sheets=1 ;
				printf("\t DEBUG |body  NR = %d\n", NR ) | "cat 1>&2" ;
				exit ;
			};
		} ;
	}{
		if( cond1 == 1 ){
			if( $0 ~ /<A HREF=/ ){
				printf("\t DEBUG |HREF  NR = %d\n", NR ) | "cat 1>&2" ;
				posN=index( $0, "#" ) ;
				if( posN > 0 ){
					rem=substr( $0, posN+1 ) ;
					posL=index( rem, ">" ) ;
					indxS++ ;
					sheetNames[indxS]=substr( rem, 1, posL-2 ) ;

					rem2=substr( rem, posL+1 ) ;
					posE=index( rem2, "</A>" ) ;
					sheetLabels[indxS]=substr( rem2, 1, posE-1 ) ;
				} ;
			}else{
				if( $0 ~ /<[/]center>/ ){
					indx=1 ;
					lookMatch=1;
					printf("\t DEBUG |center  NR = %d\n", NR ) | "cat 1>&2" ;
				} ;
			} ;
		}else{
			if( $0 ~ /<h1>Overview</ ){
				printf("\t DEBUG |Overview  NR = %d\n", NR ) | "cat 1>&2" ;
				cond1=1 ;
			} ;
		} ;
	} ;

}END{
	if( sheets == 1 ){
		for( i=1 ; i <= indxS ; i++ ){
			outfile=sprintf("%s__Sheet%03d.html", pref, i ) ;

			printf("\t Saving \"%s\" to \"%s\" ...\n", sheetNames[i], outfile) | "cat 1>&2" ;
			printf("%03d🮐%s🮐%s🮐%d🮐%d🮐\n", i, sheetNames[i], sheetLabels[i], sheetStart[i], sheetEnd[i] ) | "cat 1>&2" ; 

			abandon=0 ;
			first=1 ;
			rindx=0 ;
			do {
				if( ( getline aLine <mono ) > 0 ){
					rindx++ ;
					#print aLine | "cat 1>&2" ;
					###	Add 1 to suppress the LO-generated HTML header line
					if( rindx >= sheetStart[i]+1 && rindx <= sheetEnd[i] ){
						if( first == 1 ){
							openHTML() ;
							first=0 ;
						} ;
						print aLine >>outfile ;
					} ;
				}else{
					abandon=1 ;
					closeHTML() ;
					close(outfile) ;
					close(mono) ;
				} ;
			} while( abandon == 0 ) ;
		} ;
	}else{
		printf("\n\t Input file does not conform to expected format.  Unable to identify distinct spreadsheet tabs for extraction.\n" ) ;
		exit 1 ;
	} ;
}'

echo ""
ls -l ${outPref}__Sheet*.html

}

phase_01

phase_02
