#include <stdio.h>
#include <stdlib.h>
#include <string.h>
void print(char* line){
	printf("%s",line);
}

void printRed(char* line){
	printf("\x1b[31m%s\x1b[0m",line );
}
void printlnRed(char* line){
	printf("\x1b[31m%s\x1b[0m\n",line );
}
void printGreen(char* line){
	printf("\x1b[32m%s\x1b[0m",line );
}
void printlnGreen(char* line){
	printf("\x1b[32m%s\x1b[0m\n",line );
}
void printBlue(char* line){
	printf("\x1b[34m%s\x1b[0m",line );
}
void printlnBlue(char* line){
	printf("\x1b[34m%s\x1b[0m\n",line );
}
void printYellow(char* line){
	printf("\x1b[33m%s\x1b[0m",line );
}
void printlnYellow(char* line){
	printf("\x1b[33m%s\x1b[0m\n",line );
}
void printMagenta(char*  line){
	printf("\x1b[35m%s\x1b[0m",line );
}
void printlnMagenta(char*  line){
	printf("\x1b[35m%s\x1b[0m\n",line );
}
void printCyan(char* line){
	printf("\x1b[36m%s\x1b[0m",line );
}
void printlnCyan(char* line){
	printf("\x1b[36m%s\x1b[0m\n",line );
}

int length(char* line){
	return strlen(line);
}

int getFileLineCount(char* fileName){
	FILE *stream = fopen(fileName,"r");
	if (stream == NULL)
		return 0;
	char *line = NULL;
	int lines = 0;
	size_t len = 0, read;
	while ((read = getline(&line, &len, stream)) != -1)
		++lines;
	fclose(stream);
	free(line);
	return lines;
}

int main(void)
{
	int lines = getFileLineCount("program.txt");
     int* data = malloc(3 * sizeof(int));

	char buffer[20];
	sprintf(buffer,"%d",lines);
	printlnMagenta(buffer);

	return 0;
}