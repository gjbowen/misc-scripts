CREATE OR REPLACE PACKAGE MY_SCHEMA.K_HELPER_FUNCTIONS
IS

/*	
	CREATED BY GREG BOWEN
	---------------------------------------------------------------
	This package creates simplicity to Oracle PL/SQL functionality
*/

	TYPE array_type IS TABLE OF VARCHAR2(32767) ;

	PROCEDURE p_csv_add_column(FILE_NAME VARCHAR2,column_string VARCHAR2);
	
	FUNCTION f_file_exists(p_file_name VARCHAR2,p_location VARCHAR2) RETURN VARCHAR2;

	PROCEDURE p_file_prepend(p_filename VARCHAR2,p_location VARCHAR2,p_string  VARCHAR2);
	
	FUNCTION f_file_to_array_of_lines (FILE_NAME VARCHAR2,FILE_HEADER VARCHAR2) RETURN array_type;
	
	FUNCTION f_string_to_array  (p_list VARCHAR2,p_delim VARCHAR2)  RETURN array_type;

	FUNCTION f_csv_to_array  (p_list VARCHAR2)  RETURN array_type;
	
	FUNCTION f_file_to_array_of_tokens(FILE_NAME VARCHAR2,DELIMITOR VARCHAR2,FILE_HEADER VARCHAR2) RETURN array_type;
	
	FUNCTION  f_table_to_array(TABLE_NAME VARCHAR2,DELIMITOR VARCHAR2) RETURN array_type;

	PROCEDURE p_cursor_helper(p_table VARCHAR2, p_col VARCHAR2,cur OUT NOCOPY sys_refcursor) ;

	FUNCTION f_get_file_row_count(FILE_NAME  VARCHAR2,FILE_HEADER VARCHAR2) RETURN INTEGER;

	FUNCTION f_verify_ext_table(P_TABLE_NAME VARCHAR2, FILE_NAME VARCHAR2,DELIMITOR VARCHAR2,FILE_HEADER VARCHAR2) RETURN INTEGER;
	
	FUNCTION f_string_in_file (p_file_name VARCHAR2,p_location VARCHAR2, p_string VARCHAR2) RETURN VARCHAR2;

	PROCEDURE p_string_in_file_dbms (p_file_name VARCHAR2,p_location VARCHAR2, p_string VARCHAR2, p_found_message  VARCHAR2, p_fail_message VARCHAR2);
	
END K_HELPER_FUNCTIONS;
/

CREATE OR REPLACE PACKAGE BODY MY_SCHEMA.K_HELPER_FUNCTIONS
IS


	PROCEDURE p_csv_add_column(file_name in varchar2,column_string in varchar2) 
	IS 
		--CREATED: Greg Bowen
		--DATE: 4/25/2019
		--DESCRIPTION: adds an additional column to a csv file with a given string. use null for empty column. 
		v_file_output		   	UTL_FILE.file_type; 
		v_pathout			   	varchar2(50);
		v_file				  	array_type := array_type();
	BEGIN

	v_file := MY_SCHEMA.K_HELPER_FUNCTIONS.F_FILE_TO_ARRAY_OF_LINES(file_name, 'N');

	v_pathout	   := '/u03/export/' || upper(ua_baninst1.f_getinstance);
	v_file_output   := UTL_FILE.FOPEN(v_pathout,file_name,'w');

	for i in 1..v_file.count LOOP
		UTL_FILE.PUT_LINE(v_file_output, v_file(i)||','||column_string);   
	END LOOP;

	UTL_FILE.FCLOSE(v_file_output);

EXCEPTION 
	WHEN OTHERS THEN
		UTL_FILE.FCLOSE(v_file_output);
		DBMS_OUTPUT.PUT_LINE('ERROR in p_csv_add_column - '|| SQLERRM);
END;


	PROCEDURE p_string_in_file_dbms (p_file_name in varchar2,p_location in varchar2, p_string in varchar2, p_found_message in varchar2, p_fail_message in varchar2) 
	IS
		--CREATED: Greg Bowen
		--DATE: 1/10/2018
		--DESCRIPTION: calls f_string_in_file to write a dbms_output that's ideal for AppWorx Output Scans
	BEGIN
		IF f_string_in_file(p_file_name,p_location, p_string) = 'Y' THEN
			DBMS_OUTPUT.PUT_LINE(p_found_message);
		ELSE
			DBMS_OUTPUT.PUT_LINE(p_fail_message);	  
		END IF;
	EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE('ERROR in p_string_in_file_dbms - '|| SQLERRM);
	END p_string_in_file_dbms;

	FUNCTION f_string_in_file (p_file_name in varchar2,p_location in varchar2, p_string in varchar2) 
	RETURN varchar2
	IS
		--CREATED: Greg Bowen
		--DATE: 1/10/2018
		--DESCRIPTION: give the file name, location (import/export), and the search string for a 'Y' or 'N' return
				
	
		v_dbname			VARCHAR2(15);
		line				VARCHAR2(32767);
		v_pathin			VARCHAR2(50);
		v_file_in		   	UTL_FILE.file_type; 
		v_found			 	VARCHAR2(1):='N';
	BEGIN
		if  K_HELPER_FUNCTIONS.F_FILE_EXISTS(p_file_name, p_location)='N' then
			DBMS_OUTPUT.PUT_LINE('ORA-29283: file does not exist');
			return 'N';
		end if;
		v_dbname := ua_baninst1.f_getinstance;
		v_pathin := '/u03/'||p_location||'/' || upper(v_dbname);	
		
		v_file_in := UTL_FILE.FOPEN(v_pathin,p_file_name,'R',32767);  
		
		LOOP
			BEGIN
				--get the line
				UTL_FILE.get_line(v_file_in,line);
				--parse the line into tokens
				if REGEXP_COUNT(line,p_string)>0 THEN
					v_found := 'Y';
					exit;
				END IF;
			EXCEPTION
				WHEN no_data_found THEN
					exit;
				WHEN OTHERS THEN
					DBMS_OUTPUT.PUT_LINE('ERROR in f_string_in_file: 98'|| SQLERRM);
					exit;
			END;
		END LOOP;
		
		return v_found;
	EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE('ERROR in f_string_in_file - '|| SQLERRM);
			return 'N';
	END f_string_in_file;

	FUNCTION f_file_exists (p_file_name in varchar2,p_location in varchar2) 
	RETURN varchar2
	IS
		--CREATED: Greg Bowen
		--DATE: 8/24/2018
		--DESCRIPTION: Validate that a file exists
		v_dbname			VARCHAR2(15);
		v_pathin			VARCHAR2(50);
		v_file_in		   	UTL_FILE.file_type; 
	BEGIN
		BEGIN 
			v_dbname := ua_baninst1.f_getinstance;
			v_pathin := '/u03/'||lower(p_location)||'/' || upper(v_dbname);
			v_file_in := UTL_FILE.FOPEN(v_pathin,p_file_name,'R',32767);  
			UTL_FILE.FCLOSE(v_file_in);
		EXCEPTION
			WHEN OTHERS THEN
				-- AppWorx-based reports may need to state in the report that the file doesn't exist instead of it Aborting, so don't DBMS_OUTPUT output ORA-
				-- other file-based functions in this package will state "ORA- File does not exist" instead of it giving a generic "ORA- invalid file operation"
				-- DBMS_OUTPUT.PUT_LINE('ORA-29283: file does not exist'); 
				DBMS_OUTPUT.PUT_LINE('File does not exist: '||v_pathin||'/'||p_file_name);
				return 'N';
		END;
		return 'Y';
	EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE('ERROR 99 in f_file_exists - '|| SQLERRM);
			return 'N';
	END f_file_exists;



	PROCEDURE P_FILE_PREPEND(p_filename in varchar2,p_location in varchar2,p_string in varchar2)
	IS
		--CREATED: Greg Bowen
		--DATE: 1/10/2018
		--DESCRIPTION: pass the string of the filename and the string that you want to put at the top of the file
			
		--STEPS: 
		--  1) CLOSE the file (if open)
		--  2) Call the function with the string you want on the top of the file
		--  3) Re-open in APPEND mode (if you wish to continue writing
		
		--EXAMPLE:
		--	v_file_in := UTL_FILE.FOPEN(v_pathin,'report.txt','W');
		--	UTL_FILE.PUT_LINE(v_file_in, 'bravo');	  
		--	UTL_FILE.FCLOSE(v_file_in);
		--	
		--	---put something at the top.
		--	k_helper_functions.p_file_prepend('report.txt','alpha');
		--	
		--	--then keep going....
		--	v_file_in := UTL_FILE.FOPEN(v_pathin,'report.txt','A');
		--	UTL_FILE.PUT_LINE(v_file_in, 'charlie');	  
		--	UTL_FILE.FCLOSE(v_file_in);	
	
		v_dbname			VARCHAR2(15);
		line				VARCHAR2(32767);
		v_pathin			VARCHAR2(50);
		v_pathout		   	VARCHAR2(50);
		v_file_in		   	UTL_FILE.file_type; 
		v_file_contents	 	K_HELPER_FUNCTIONS.ARRAY_TYPE :=  K_HELPER_FUNCTIONS.ARRAY_TYPE();
		
	BEGIN
		if  K_HELPER_FUNCTIONS.F_FILE_EXISTS(p_filename, p_location)='N' then
			DBMS_OUTPUT.PUT_LINE('ORA-29283: file does not exist');
			return;
		end if;
		v_dbname := ua_baninst1.f_getinstance;
			
		if upper(p_location) = 'IMPORT' THEN
			v_pathin := '/u03/import/' || upper(v_dbname);	
		else
			v_pathin := '/u03/export/' || upper(v_dbname);		
		end if;
		
		--all files must go to EXPORT to prevent permission issues from Owner: AppWorx
		v_pathout := '/u03/export/' || upper(v_dbname);		

		v_file_in := UTL_FILE.FOPEN(v_pathin,p_filename,'R',32767);  
		
		LOOP
			BEGIN
				UTL_FILE.get_line(v_file_in,line);
				v_file_contents.EXTEND;
				v_file_contents(v_file_contents.COUNT):=line;
			EXCEPTION
				WHEN no_data_found THEN
					exit;
				WHEN OTHERS THEN
					DBMS_OUTPUT.PUT_LINE('ERROR: 99');
					exit;
			END;
		END LOOP;
		UTL_FILE.FCLOSE(v_file_in);

		--write array to file
		v_file_in := UTL_FILE.FOPEN(v_pathout,p_filename,'W');

		UTL_FILE.PUT_LINE(v_file_in, p_string);	  
		for i in 1..v_file_contents.count loop
			UTL_FILE.PUT_LINE(v_file_in, v_file_contents(i));
		END LOOP;
		
		UTL_FILE.FCLOSE(v_file_in);
		DBMS_OUTPUT.PUT_LINE('Successfully prepended '''||p_string||''' to file '||p_filename);
	EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE('ERROR in P_FILE_PREPEND - '|| SQLCODE ||'   '|| SQLERRM(SQLCODE) );
	END P_FILE_PREPEND;

	FUNCTION f_table_to_array(TABLE_NAME in VARCHAR2,DELIMITOR in VARCHAR2)
	RETURN array_type
	as

		v_column_name	   	USER_TAB_COLUMNS.COLUMN_NAME%TYPE;
		v_data_type		 	USER_TAB_COLUMNS.DATA_TYPE%TYPE;
		v_data_length	   	USER_TAB_COLUMNS.DATA_LENGTH%TYPE;
		v_column_id		 	NUMBER;
		v_first_time		VARCHAR2(1):='Y';
		
		v_columns_string	VARCHAR2(32767);
		
		v_line			  	VARCHAR2(32767);
			
		v_table_name		VARCHAR2(40);
		
		c_records		   	SYS_REFCURSOR;
			
		v_valid			 	NUMBER;
		v_schema			SYS.user_users.username%TYPE; 
		
		
		--GET NAME OF COLUMNS 
		CURSOR get_columns IS
		SELECT DISTINCT column_name,data_type,data_length,column_id
		FROM ALL_TAB_COLUMNS 
		WHERE OWNER=upper(v_schema)
		and table_name = upper(v_table_name)
		order by column_id;

		v_contents		  K_HELPER_FUNCTIONS.array_type :=  array_type();
		
	BEGIN	
		--check to see if table exists
		v_table_name:=substr(TABLE_NAME,instr(TABLE_NAME,'.')+1);
		v_schema:=substr(TABLE_NAME,
						1,--start position
						instr(TABLE_NAME,'.')-1);--stop position

		if v_schema is null THEN
			SELECT distinct username 
			INTO v_schema 
			FROM user_users; 
		end if;
		--get the ALL of the column names
		BEGIN
			SELECT distinct 1
			into v_valid
			FROM ALL_TAB_COLUMNS 
			WHERE upper(OWNER) = upper(v_schema)
			and upper(TABLE_NAME) = upper(v_table_name);
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				DBMS_OUTPUT.PUT_LINE('Table "'||v_table_name||'" does not exist in schema ' || nvl('"'||v_schema||'"',' '));
				DBMS_OUTPUT.PUT_LINE('Possibly a permissions issue.');
		END;
		
		OPEN get_columns;
			LOOP 
			FETCH get_columns INTO v_column_name,v_data_type,v_data_length,v_column_id;
			EXIT WHEN get_columns %NOTFOUND;  
				IF v_first_time='Y' THEN
					v_columns_string := v_column_name;
					v_first_time:='N';
				ELSE
					v_columns_string:=v_columns_string||'||'''||DELIMITOR||'''||'||v_column_name;
				END IF;
			END LOOP;
		CLOSE get_columns;
		
		--dynamic getting of cursor with table name as a string
		p_cursor_helper(TABLE_NAME,v_columns_string, c_records);
	   
		LOOP
		FETCH c_records INTO v_line;
		EXIT WHEN c_records%NOTFOUND;
			IF v_line is not null then				
				v_contents.EXTEND;
				v_contents(v_contents.COUNT):=v_line;

			end if;
		end loop;

		CLOSE c_records;
		return v_contents;
	EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE('Error in f_table_to_array - ' || SQLERRM(SQLCODE)); 
			RETURN NULL;
	END f_table_to_array;

	------------------------------------------------------------------------------------------------------------

	PROCEDURE p_cursor_helper(
		   p_table IN VARCHAR2, 
		   p_col IN VARCHAR2,
		   cur OUT NOCOPY sys_refcursor) 
	as
		query_str   VARCHAR2(32000);
	BEGIN
		query_str := 'SELECT '||upper(p_col)||' FROM ' || upper(p_table);
		OPEN cur FOR query_str;
	EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE('ERROR IN f_table_to_array - '|| SQLERRM(SQLCODE));
	END p_cursor_helper;

	------------------------------------------------------------------------------------------------------------
	
	FUNCTION f_verify_ext_table(P_TABLE_NAME IN VARCHAR2, FILE_NAME IN VARCHAR2,DELIMITOR IN VARCHAR2,FILE_HEADER IN VARCHAR2)
		RETURN INTEGER
	IS
		--CREATED: Greg Bowen
		--DATE: 5/18/2017
		--DESCRIPTION: 
		--IF file contains header, set third parameter to 'Y'
		--compare mode: compares ext table and file to return true=0 false=1 or error=-1
			
		--example: user wants to verify external table being read has correct data types
		--return  true=0 false=1 and error=-1

		v_table_count	   	NUMBER;
		v_row_count		 	NUMBER:=0;
		v_dbname			VARCHAR2(15);
		line				VARCHAR2(32767);
		v_pathin			VARCHAR2(50);
		v_file_in		   	UTL_FILE.file_type; 
		v_table_array	   	K_HELPER_FUNCTIONS.array_type:=  K_HELPER_FUNCTIONS.array_type();
		v_file			  	K_HELPER_FUNCTIONS.array_type:=  K_HELPER_FUNCTIONS.array_type();
		v_items			 	K_HELPER_FUNCTIONS.array_type:=  K_HELPER_FUNCTIONS.array_type();
		v_temp_line		 	VARCHAR2(32767);
		v_data_length	   	NUMBER;
		v_column_name	   	VARCHAR2(200);
		v_column_count	  	NUMBER:=0;
		v_table_name		VARCHAR2(50);
		v_schema			VARCHAR2(20);
	BEGIN
		if  K_HELPER_FUNCTIONS.F_FILE_EXISTS(FILE_NAME, 'import')='N' then
			DBMS_OUTPUT.PUT_LINE('ORA-29283: file does not exist');
			return -1;
		end if;
		v_dbname := ua_baninst1.f_getinstance;
		v_pathin := '/u03/import/' || upper(v_dbname);		
		v_file_in := UTL_FILE.FOPEN(v_pathin,FILE_NAME,'R',32767);
		
		v_table_name:=substr(P_TABLE_NAME,instr(P_TABLE_NAME,'.')+1);
		v_schema:=substr(P_TABLE_NAME,
						1,--start position
						instr(P_TABLE_NAME,'.')-1);--stop position
		LOOP
			BEGIN
				UTL_FILE.GET_LINE(v_file_in,line);
				v_row_count := v_row_count + 1;
			EXCEPTION 
				WHEN No_Data_Found THEN 
					EXIT; 
				WHEN OTHERS THEN
					DBMS_OUTPUT.PUT_LINE('Error in f_verify_ext_table encountered: '||SQLCODE||' -ERROR- '||SQLERRM);
			END;
		END LOOP;
		UTL_FILE.FCLOSE(v_file_in); 
		
		IF UPPER(FILE_HEADER) = 'Y' THEN
			v_row_count := v_row_count - 1;
		END IF;

		IF P_TABLE_NAME is null then --return count of rows in file
			DBMS_OUTPUT.PUT_LINE('A TABLE NAME WAS NOT GIVEN!');
			return -1;
		END IF; 
		
		BEGIN 
			EXECUTE IMMEDIATE 'select count(*) from ' || P_TABLE_NAME INTO v_table_count;
			--means it's good. 
			IF v_table_count = v_row_count THEN
				RETURN 0;
			END IF;
			--if not, go compare each column and see what's wrong.
			IF UPPER(FILE_HEADER) = 'Y' THEN 
				v_row_count := 2;
			ELSE 
				v_row_count :=1;
			END IF;	
			EXECUTE IMMEDIATE 'select count(*) from SYS.ALL_TAB_COLS where TABLE_NAME = '''||upper(v_table_name)||''''  INTO v_column_count ;
			DBMS_OUTPUT.PUT_LINE('# of columns in table: '||v_column_count);
			v_file := K_HELPER_FUNCTIONS.F_FILE_TO_ARRAY_OF_LINES(FILE_NAME,FILE_HEADER);
			v_table_array := K_HELPER_FUNCTIONS.F_TABLE_TO_ARRAY (P_TABLE_NAME,DELIMITOR);

			FOR i in 1..v_file.count LOOP
				v_temp_line := v_file(i); --assign to different variable for replacing delimitors
				IF v_temp_line  not member of v_table_array THEN --check to see if they file is being read correctly
					v_items := K_HELPER_FUNCTIONS.f_string_to_array(v_temp_line,DELIMITOR);

					for j in 1..v_items.count LOOP
						BEGIN
							select column_name,char_length 
							into v_column_name, v_data_length
							from all_tab_columns 
							where TABLE_NAME = UPPER(v_table_name)
							and column_id = j;
							IF v_data_length < length(v_items(j)) THEN --TOO BIG!!
								DBMS_OUTPUT.PUT_LINE('Line: '||v_row_count||' - '||v_column_name||' is '||length(v_items(j))||'. Max: '|| v_data_length ||'	Contents: '||v_items(j));
							END IF;
						EXCEPTION
							WHEN NO_DATA_FOUND THEN
								DBMS_OUTPUT.PUT_LINE('Record (line '||v_row_count||') exceeded NUMBER of columns in external table.');
								exit;
							WHEN OTHERS THEN
								DBMS_OUTPUT.PUT_LINE('Error in f_verify_ext_table encountered - '||SQLERRM(SQLCODE));
						END;	
					END LOOP;
				END IF;
				v_row_count:=v_row_count+1;
			END LOOP;
		
			RETURN 1;
			
		EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE('Error in f_verify_ext_table encountered 96: - '||SQLCODE||' -ERROR- '||SQLERRM(SQLCODE));
				RETURN -1;
		END;   
		   
	EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE('Error in f_verify_ext_table encountered 97: - '||SQLCODE||' -ERROR- '||SQLERRM(SQLCODE));
			RETURN -1;
	END f_verify_ext_table;
	
	------------------------------------------------------------------------------------------------------------
	
	FUNCTION f_get_file_row_count(FILE_NAME IN VARCHAR2,FILE_HEADER IN VARCHAR2)
	   RETURN INTEGER
	IS
		--CREATED: Greg Bowen
		--DATE: 5/18/2017
		--DESCRIPTION: return row count of lines in a specified file
		--			  IF file contains header, set third parameter to 'Y'
		v_dbname			VARCHAR2(10);
		v_pathin			VARCHAR2(50);

		v_row_count		 	NUMBER:=0;
		
		line				VARCHAR2(32767);
		v_file_in		   	UTL_FILE.file_type; 
		
	BEGIN
		if  K_HELPER_FUNCTIONS.F_FILE_EXISTS(FILE_NAME, 'import')='N' then
			DBMS_OUTPUT.PUT_LINE('ORA-29283: file does not exist');
			return null;
		end if;
		
		v_dbname := ua_baninst1.f_getinstance;
		v_pathin := '/u03/import/' || upper(v_dbname);		
		v_file_in := UTL_FILE.FOPEN(v_pathin,FILE_NAME,'R',32767);
		LOOP
			BEGIN
				UTL_FILE.GET_LINE(v_file_in,line);
				v_row_count := v_row_count + 1;
			EXCEPTION 
				WHEN No_Data_Found THEN 
					EXIT; 
				WHEN OTHERS THEN
					DBMS_OUTPUT.PUT_LINE('Error in f_get_file_row_count reading file: '||SQLCODE||' -ERROR- '||SQLERRM);
			END;
		END LOOP;
		UTL_FILE.FCLOSE(v_file_in); 
		
		IF UPPER(FILE_HEADER) = 'Y' THEN
			v_row_count := v_row_count - 1;
		END IF;

		return v_row_count;
		
	EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE('ERROR in f_get_file_row_count: - '||SQLCODE||' -ERROR- '||SQLERRM(SQLCODE));
			RETURN null;
	END f_get_file_row_count;

	------------------------------------------------------------------------------------------------------------

	FUNCTION f_file_to_array_of_tokens (FILE_NAME IN VARCHAR2,DELIMITOR IN VARCHAR2,FILE_HEADER IN VARCHAR2)  
	RETURN array_type
	AS
		v_file		  	array_type := array_type(); --array of lines
		v_line		  	array_type := array_type(); --array of words of the line
		v_words		 	array_type := array_type(); --array of words in the file
	BEGIN
		v_file := K_HELPER_FUNCTIONS.F_FILE_TO_ARRAY_OF_LINES(FILE_NAME,FILE_HEADER);
		for line in 1..v_file.count loop
			--now looking at each line. current line = v_file(line)
			v_line := K_HELPER_FUNCTIONS.F_STRING_TO_ARRAY( v_file(line),DELIMITOR);
			--v_line is arrary of words in the line
			for word in 1..v_line.count loop
				--add each line to a new array
				v_words.EXTEND;
				v_words(v_words.COUNT):=v_line(word);
			end loop;		
		end loop;
		return v_words;
	EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE('ERROR IN F_STRING_TO_ARRAY_OF_WORDS - '|| SQLERRM);
			RETURN NULL;
	END f_file_to_array_of_tokens;
	
	------------------------------------------------------------------------------------------------------------

	FUNCTION f_file_to_array_of_lines (FILE_NAME IN VARCHAR2,FILE_HEADER IN VARCHAR2)
	RETURN array_type
	AS
	v_dbname			VARCHAR2(10);
	v_pathin			VARCHAR2(50);
	line				VARCHAR2(32767);
	v_file_in		   	UTL_FILE.file_type; 
	  
	l_tab			   	array_type := array_type();
	v_skip			  	VARCHAR2(1);
	BEGIN

		if  K_HELPER_FUNCTIONS.F_FILE_EXISTS(FILE_NAME, 'import')='N' then
			DBMS_OUTPUT.PUT_LINE('ORA-29283: file does not exist');
			return null;
		end if;

		v_dbname := ua_baninst1.f_getinstance;
		v_pathin := '/u03/import/' || upper(v_dbname);		
		v_file_in := UTL_FILE.FOPEN(v_pathin,FILE_NAME,'R',32767);
		
		IF FILE_HEADER ='Y' THEN
			v_skip:='Y';
		ELSE
			v_skip:='N';
		END IF;
		
		LOOP
			BEGIN
				UTL_FILE.get_line(v_file_in,line);
				if v_skip = 'N' THEN
					l_tab.EXTEND;
					l_tab(l_tab.COUNT):=replace(line,chr(13),'');
				ELSE
					v_skip:='N';
				END IF;
			EXCEPTION
				WHEN no_data_found THEN
					exit;
				WHEN OTHERS THEN
					DBMS_OUTPUT.PUT_LINE('ERROR in f_file_to_array_of_lines');
					exit;
			END;
		END LOOP;
		UTL_FILE.FCLOSE(v_file_in);
		RETURN l_tab;
		
	EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE('ERROR IN f_file_to_array_of_lines - '|| SQLERRM);
			UTL_FILE.FCLOSE(v_file_in);
			return null;
	END f_file_to_array_of_lines;
	
	------------------------------------------------------------------------------------------------------------
	
	FUNCTION f_string_to_array(p_list IN VARCHAR2,p_delim IN VARCHAR2)
		RETURN array_type
		AS
		l_string	   VARCHAR2(32767) := replace(p_list,p_delim||p_delim,p_delim||NULL||p_delim) || p_delim;
		l_comma_index  PLS_INTEGER;
		current_index  PLS_INTEGER := 1;
		l_tab		  array_type := array_type();
		v_array		array_type := array_type();
		
	BEGIN
	
		LOOP
		l_comma_index := INSTR(l_string, p_delim, current_index);--return index of next comma..			
		EXIT WHEN l_comma_index = 0;
			l_tab.EXTEND;
			l_tab(l_tab.COUNT) := SUBSTR(l_string, --source string
										current_index, --start position
										l_comma_index - current_index); --length
			current_index := l_comma_index + 1;
		END LOOP;
		
		IF p_delim = ' ' THEN
			for item in 1..l_tab.count loop
				if l_tab(item) != ' ' and l_tab(item) is not null THEN
					v_array.extend;
					v_array(v_array.count):=l_tab(item);
				END IF;
			END LOOP;
			RETURN v_array;
		END IF;
				
		RETURN l_tab;
	EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE('ERROR IN F_STRING_TO_ARRAY - '|| SQLERRM);
			RETURN NULL;
	END f_string_to_array;
	
	------------------------------------------------------------------------------------------------------------

	FUNCTION f_csv_to_array(p_list IN VARCHAR2)
		RETURN array_type
		AS

		v_new_array 	array_type := array_type();

		v_lastline  	VARCHAR2(32000);
		v_array	 		sys.odciVARCHAR2list;
	BEGIN
		v_lastline := p_list;

		select trim(replace(replace(
		regexp_substr(replace(v_lastline, ',', ',§'),
		'(§"[^"]*"|[^,]+)', 1, level), '§', null), '"', null))
		bulk collect into v_array
		from dual
		connect by regexp_substr(replace(v_lastline, ',', ',§'),
		'(§"[^"]*"|[^,]+)', 1, level) is not null;

		for i in 1..v_array.count loop
			v_new_array.extend;
			IF v_array(i) = chr(13) THEN
				v_new_array(v_new_array.count):=NULL;
			ELSE
				v_new_array(v_new_array.count):=v_array(i);	 
			END IF;   
		end loop; 
		
		RETURN v_new_array;
	EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE('ERROR IN F_CSV_TO_ARRAY - '|| SQLERRM);
			RETURN NULL;
	END f_csv_to_array;
END K_HELPER_FUNCTIONS;
/