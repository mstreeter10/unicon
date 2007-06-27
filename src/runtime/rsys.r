/*
 * File: rsys.r
 *  Contents: [flushrec], [getrec], getstrg, host, longread, [putrec], putstr
 */

#ifdef RecordIO
/*
 * flushrec - force buffered output to be written with a record break.
 *  Applies only to files with mode "s".
 */

void flushrec(fd)
FILE *fd;
{
#if SASC
   afwrite("", 1, 0, fd);
#endif					/* SASC */
}

/*
 * getrec - read a record into buf from file fd. At most maxi characters
 *  are read.  getrec returns the length of the record.
 *  Returns -1 if EOF and -2 if length was limited by
 *  maxi. [[ Needs ferror() check. ]]
 *  This function is meaningful only for files opened with mode "s".
 */

int getrec(buf, maxi, fd)
register char *buf;
int maxi;
FILE *fd;
   {
#ifdef SASC
   register int l;

   l = afreadh(buf, 1, maxi+1, fd);     /* read record or maxi+1 chars */
   if (l == 0) return -1;
   if (l <= maxi) return l;
   ungetc(buf[maxi], fd);               /* if record not used up, push
                                           back last char read */
   return -2;
#endif					/* SASC */
   }
#endif					/* RecordIO */

#ifdef PosixFns
#ifndef SOCKET_ERROR
#define SOCKET_ERROR -1
#endif
/*
 * sock_getstrg - read a line into buf from socket.  
 *  At most maxi characters are read.  sock_getstrg returns the 
 *  length of the line, not counting the newline.  Returns -1 
 *  if EOF and -3 if a socket error occur.
 */
int sock_getstrg(buf, maxi, fd)
register char *buf;
int maxi;
SOCKET fd;
   {
   int r = 0, i=0;
   char *stmp=NULL;
  
   if ((r=recv(fd, buf, maxi, MSG_PEEK))==SOCKET_ERROR) {
#if NT
      if(WSAGetLastError() == WSAESHUTDOWN)   
	 return -1;
#endif					/* NT */
      k_errornumber = 1040;
      return -3;
      }
   if (r == 0) return -1;
   
   stmp = buf;
   while (stmp - buf < r) {
      if (*stmp == '\n') break;
      stmp++;
      }

   if (stmp - buf < r) {
      if(stmp == buf)
	 i = stmp - buf + 1;
      else
	 i = stmp - buf;
      }
   else  
      i = r;
   if ((r=recv(fd, buf, i, 0)) == SOCKET_ERROR) {
#if NT
      if (WSAGetLastError() == WSAESHUTDOWN)
	 return -1;
#endif					/* NT */
      k_errornumber = 1040;
      return -3;
      }
   return r;
   }
#endif					/* NT */

#if NT
#ifndef NTGCC
#define pclose _pclose
#endif
#endif

/*
 * getstrg - read a line into buf from file fbp.  At most maxi characters
 *  are read.  getstrg returns the length of the line, not counting the
 *  newline.  Returns -1 if EOF and -2 if length was limited by maxi.
 *  Discards \r before \n in translated mode.  [[ Needs ferror() check. ]]
 */
int getstrg(buf, maxi, fbp)
register char *buf;
int maxi;
struct b_file *fbp;
   {
   register int c, l;
   FILE *fd = fbp->fd.fp;

#ifdef PosixFns
   static char savedbuf[BUFSIZ];
   static int nsaved = 0;
#endif					/* PosixFns */

#if AMIGA
#if LATTICE
   /* This code is special for Lattice 4.0.  It was different for
    *  Lattice 3.10 and probably won't work for other C compilers.
    */
   extern struct UFB _ufbs[];

   if (IsInteractive(_ufbs[fileno(fd)].ufbfh))
      return read(fileno(fd),buf,maxi);
#endif					/* LATTICE */
#endif					/* AMIGA */

#ifdef Messaging
   if (fbp->status & Fs_Messaging) {
      extern int Merror;
      struct MFile* mf = (struct MFile *)fd;

      if (strcmp(mf->tp->uri.scheme, "pop") == 0) {
	 return -1;
	 }

      if (MFIN(mf, WRITING)) {
	 Mstartreading(mf);
	 }
      if (!MFIN(mf, READING)) {
	 return -1;
	 }
      l = tp_readln(mf->tp, buf, maxi);
      if (l <= 0) {
	 tp_free(mf->tp);
	 MFSTATE(mf, CLOSED);
	 return -1;
	 }
      if (buf[l-1] == '\n') {
	 l--;
	 }
      if (fbp->status & Fs_Untrans && buf[l-1] == '\r') {
	 l--;
	 }
      return l;
      }
#endif                                  /* Messaging */

#ifdef XWindows
   wflushall();
#endif					/* XWindows */
#if NT
   if (fbp->status & Fs_Pipe) {
      if (feof(fd) || (fgets(buf, maxi, fd) == NULL)) {
         pclose(fd);
	 fbp->status = 0;
         return -1;
         }
      l = strlen(buf);
      if (l>0 && buf[l-1] == '\n') l--;
      if (l>0 && buf[l-1] == '\r' && (fbp->status & Fs_Untrans) == 0) l--;
      if (feof(fd)) {
         pclose(fd);
	 fbp->status = 0;
         }
      return l;
      }
#endif					/* NT */

   l = 0;

#ifdef PosixFns
   /* If there are saved chars in the static buffer, use those */
   if (nsaved > 0) {
      strncpy(buf, savedbuf, nsaved);
      l = nsaved;
      buf += l;
   }
#endif

   while (1) {

#ifdef Graphics
      /* insert non-blocking read/code to service windows here */
#endif					/* Graphics */

#if NT
   if (fbp->status & Fs_Pipe) {
      if (feof(fd)) {
         pclose(fd);
	 fbp->status = 0;
         if (l>0) return 1;
         else return -1;
         }
      }
#endif					/* NT */
      if ((c = fgetc(fd)) == '\n') {	/* \n terminates line */
	 break;
         }

      if (c == '\r' && (fbp->status & Fs_Untrans) == 0) {
	 /* \r terminates line in translated mode */
#if NT
   if (fbp->status & Fs_Pipe) {
      if (feof(fd)) {
         pclose(fd);
	 fbp->status = 0;
         if (l>0) return 1;
         else return -1;
         }
      }
#endif					/* NT */
	 if ((c = fgetc(fd)) != '\n')	/* consume following \n */
	     ungetc(c, fd);		/* (put back if not \n) */
	 break;
	 }
#if NT
   if (fbp->status & Fs_Pipe) {
      if (feof(fd)) {
         pclose(fd);
	 fbp->status = 0;
         if (l>0) return 1;
         else return -1;
         }
      }
#endif					/* NT */
      if (c == EOF) {
#if NT
         if (fbp->status & Fs_Pipe) {
            pclose(fd);
	    fbp->status = 0;
            }
#endif					/* NT */

#ifdef PosixFns
	 /* If errno is EAGAIN, we will not return any chars just yet */
	 if (errno == EAGAIN 
#if !NT
	    || errno == EWOULDBLOCK
#endif
	 ) {
	    return -1;
	 }
#endif					/* PosixFns */

	 if (l > 0) {
#ifdef PosixFns
	    /* Clear the saved chars buffer */
	    nsaved = 0;
#endif					/* PosixFns */
	    return l;
	    } 
	 else return -1;
	 }
      if (++l > maxi) {
	 ungetc(c, fd);
#ifdef PosixFns
	 /* Clear the saved chars buffer */
	 nsaved = 0;
#endif					/* PosixFns */
	 return -2;
	 }
#ifdef PosixFns
      savedbuf[nsaved++] = c;
#endif					/* PosixFns */
      *buf++ = c;
      }

#ifdef PosixFns
   /* We can clear the saved static buffer */
   nsaved = 0;
#endif					/* PosixFns */

   return l;
   }

/*
 * iconhost - return some sort of host name into the buffer pointed at
 *  by hostname.  This code accommodates several different host name
 *  fetching schemes.
 */
void iconhost(hostname)
char *hostname;
   {

#ifdef HostStr
   /*
    * The string constant HostStr contains the host name.
    */
   strcpy(hostname,HostStr);
#elif VMS				/* HostStr */
   /*
    * VMS has its own special logic.
    */
   char *h;
   if (!(h = getenv("ICON_HOST")) && !(h = getenv("SYS$NODE")))
      h = "VAX/VMS";
   strcpy(hostname,h);
#else					/* HostStr */
   {
   /*
    * Use the uname system call.  (POSIX)
    */
   struct utsname utsn;
   uname(&utsn);
   strcpy(hostname,utsn.nodename);
   }
#endif					/* HostStr */

   }

/*
 * Read a long string in shorter parts. (Standard read may not handle long
 *  strings.)
 */
word longread(s,width,len,fd)
FILE *fd;
int width;
char *s;
long len;
{
   tended char *ts = s;
   long tally = 0;
   long n = 0;

#if NT
   /*
    * Under NT/MSVC++, ftell() used in Icon where() returns bad answers
    * after a wlongread().  We work around it here by fseeking after fread.
    */
   long pos = ftell(fd);
#endif					/* NT */

#ifdef XWindows
   if (isatty(fileno(fd))) wflushall();
#endif					/* XWindows */

   while (len > 0) {
      n = fread(ts, width, (int)((len < MaxIn) ? len : MaxIn), fd);
      if (n <= 0) {
#if NT
         fseek(fd, pos + tally, SEEK_SET);
#endif					/* NT */
         return tally;
	 }
      tally += n;
      ts += n;
      len -= n;
      }
#if NT
   fseek(fd, pos + tally, SEEK_SET);
#endif					/* NT */
   return tally;
   }


#if HAVE_LIBZ
/*
 * Read a long string in shorter parts from a comressed file. 
 * (Standard read may not handle long strings.)
 */
word gzlongread(s,width,len,fd)
FILE *fd;
int width;
char *s;
long len;
{
   tended char *ts = s;
   long tally = 0;
   long n = 0;

#if NT
   /*
    * Under NT/MSVC++, ftell() used in Icon where() returns bad answers
    * after a wlongread().  We work around it here by fseeking after fread.
    */
   long pos = ftell(fd);
#endif					/* NT */

#ifdef XWindows
   if (isatty(fileno(fd))) wflushall();
#endif					/* XWindows */

   while (len > 0) {
      n = gzread(fd,ts, width * ((int)((len < MaxIn) ? len : MaxIn)));
      if (n <= 0) {
#if NT
         gzseek(fd, pos + tally, SEEK_SET);
#endif					/* NT */
         return tally;
	 }
      tally += n;
      ts += n;
      len -= n;
      }
#if NT
   gzseek(fd, pos + tally, SEEK_SET);
#endif					/* NT */
   return tally;
   }

#endif					/* HAVE_LIBZ */


#ifdef RecordIO
/*
 * Write string referenced by descriptor d, avoiding a record break.
 *  Applies only to files openend with mode "s".
 */

int putrec(f, d)
register FILE *f;
dptr d;
   {
#if SASC
   register char *s;
   register word l;

   l = StrLen(*d);
   if (l == 0)
      return Succeeded;
   s = StrLoc(*d);

   if (afwriteh(s,1,l,f) < l)
      return Failed;
   else
      return Succeeded;
   /*
    * Note:  Because RecordIO depends on SASC, and because SASC
    *  uses its own malloc rather than the Icon malloc, file usage
    *  cannot cause a garbage collection.  This may require
    *  reevaluation if RecordIO is supported for any other compiler.
    */
#endif					/* SASC */
   }
#endif					/* RecordIO */

/*
 * Print string referenced by descriptor d. Note, d must not move during
 *   a garbage collection.
 */

int putstr(f, d)
register FILE *f;
dptr d;
   {
   register char *s;
   register word l;
   register int  i;

   l = StrLen(*d);
   if (l == 0)
      return  Succeeded;
   s = StrLoc(*d);

#ifdef MSWindows
#ifdef ConsoleWindow
   if ((f == stdout && !(ConsoleFlags & StdOutRedirect)) ||
	(f == stderr && !(ConsoleFlags & StdErrRedirect))) {
      if (ConsoleBinding == NULL)
         ConsoleBinding = OpenConsole();
      { int i; for(i=0;i<l;i++) Consoleputc(s[i], f); }
      return Succeeded;
      }
#endif					/* ConsoleWindow */
#endif					/* MSWindows */
#ifdef PresentationManager
   if (ConsoleFlags & OutputToBuf) {
      /* check for overflow */
      if (MaxReadStr * 4 - ((int)ConsoleStringBufPtr - (int)ConsoleStringBuf) < l + 1)
	 return Failed;
      /* big enough */
      memcpy(ConsoleStringBufPtr, s, l);
      ConsoleStringBufPtr += l;
      *ConsoleStringBufPtr = '\0';
      } /* End of if - push to buffer */
   else if ((f == stdout && !(ConsoleFlags & StdOutRedirect)) ||
	    (f == stderr && !(ConsoleFlags & StdErrRedirect)))
      wputstr((wbinding *)PMOpenConsole(), s, l);
   return Succeeded;
#endif					/* PresentationManager */
#if VMS
   /*
    * This is to get around a bug in VMS C's fwrite routine.
    */
   {
      int i;
      for (i = 0; i < l; i++)
         if (putc(s[i], f) == EOF)
            break;
      if (i == l)
         return Succeeded;
      else
         return Failed;
   }
#else					/* VMS */
   if (longwrite(s,l,f) < 0)
      return Failed;
   else
      return Succeeded;
#endif					/* VMS */
   }

/*
 * Wait for input to become available on fd, with timeout of t ms
 */
iselect(fd, t)
int fd, t;
   {

#ifdef PosixFns
   struct timeval tv;
   fd_set fds;
   tv.tv_sec = t/1000;
   tv.tv_usec = (t % 1000) * 1000;
#if !NT
   FD_ZERO(&fds);
#endif					/* NT */
   FD_SET(fd, &fds);
   return select(fd+1, &fds, NULL, NULL, &tv);
#else					/* PosixFns */
   return -1;
#endif					/* PosixFns */

   }

/*
 * idelay(n) - delay for n milliseconds
 */
int idelay(n)
int n;
   {
   if (n <= 0) return Succeeded; /* delay < 0 = no delay */

/*
 * The following code is operating-system dependent [@fsys.01].
 */
#if OS2
#if OS2_32
   DosSleep(n);
   return Succeeded;
#else					/* OS2_32 */
   return Failed;
#endif					/* OS2_32 */
#endif					/* OS2 */

#if VMS
   delay_vms(n);
   return Succeeded;
#endif					/* VMS */

#if SASC
   sleepd(0.001*n);
   return Succeeded;
#endif                                   /* SASC */

#if UNIX
   {
   struct timeval t;
   t.tv_sec = n / 1000;
   t.tv_usec = (n % 1000) * 1000;
   select(1, NULL, NULL, NULL, &t);
   return Succeeded;
   }
#endif					/* UNIX */

#if MSDOS
#if SCCX_MX
   msleep(n);
   return Succeeded;
#else					/* SCCX_MX */
#if NT
#ifdef MSWindows
   Sleep(n);
#else					/* MSWindows */
   /*
    * In the old DOS documentation, sleep(n) took a # of seconds to sleep,
    * but VC++ 2.0's _sleep() seems to be taking milliseconds.
    */
   _sleep(n);

#endif					/* MSWindows */
   return Succeeded;
#else					/* NT */
   return Failed;
#endif					/* NT */
#endif					/* SCCX_MX */
#endif					/* MSDOS */

#if MACINTOSH
   void MacDelay(int n);
   MacDelay(n);
   return Succeeded;
#endif					/* MACINTOSH */


#if AMIGA
#if __SASC
   Delay(n/20);
   return Succeeded;
#else					/* __SASC */
   return Failed
#endif                                  /* __SASC */
#endif					/* AMIGA */

#if PORT || ARM || MVS || VM
   return Failed;
#endif					/* PORT || ARM || ... */

   /*
    * End of operating-system dependent code.
    */
   }

#ifdef Network

/* 
 * parsing the url, separate scheme, host, port, path parts 
 * the function calling it allocate space for variables scheme,
 * host, port, and path.
*/

void parse_url(char *url, char *scheme, char *host, int *port, char *path)
{
   char *slash, *colon;
   char *delim;
   char turl[MAXPATHLEN]; /* MAXPATHLEN = 1024 in sys/param.h */
   char *t;
   int NOHOST = 0;

   /* All operations on turl so as not to mess contents of url */
  
   strcpy(turl, url);

   delim = "://";

   if ((colon = strstr(turl, delim)) == NULL) {
      if ( *turl == '/' ) {
         strcpy(scheme, "file");
	 NOHOST = 1;
	 t = turl + 1;
      }
      else {
	 strcpy(scheme, "http");
	 t = turl;
      }
   } 
   else {
      *colon = '\0';
      strcpy(scheme, turl);
      if ( strcasecmp(scheme, "file") == 0 )
	 NOHOST = 1;
      t = colon + strlen(delim);
   }

   /* Now t points to the beginning of host name */

   if ((slash = strchr(t, '/')) == NULL) {
      /* If there isn't even one slash, the path must be empty */
      if ( NOHOST == 0 ) {
         strcpy(host, t);
	 strcpy(path, "/");
      }
      else {
	 host = NULL; 
	 strcpy(path, "/");
	 strcat(path, t);
      }
   } 
   else {
      if ( NOHOST == 0 ) {		
         strcpy(path, slash);
	 *slash = '\0';	/* Terminate host name */
	 strcpy(host, t);
      }
      else {
	 strcpy(path, "/");
	 strcat(path, t);
	 host = NULL;
      }
   }

   /* Check if the hostname includes ":portnumber" at the end */

   if ( NOHOST == 0 ) {
      if ((colon = strchr(host, ':')) == NULL) 
	 *port = 80;	/* HTTP standard */
      else {
	 *colon = '\0';
	 if (isdigit(colon[1])) *port = atoi(colon + 1);
	 else {
	    /*
	     * : with no number following (site:/file) denotes the default port
	     */
	    *port = 80;
	    }
      }
   }
}

void myhandler(int i)
{
fprintf(stderr, "I am handling things by not handling them\n");
}

/* 
 * urlopen opens a local file or a remote file depending on the url input.
 * It checks the http_proxy environment variable. If it is set, then sending
 * the request to the proxy server for the remote file, otherwise, only support
 * sending the http request to the remote http server for retrieving the file
 * at the remote site.
 */
 
int urlopen(char *url, int flag, struct netfd *retval)
{
   char request[MAXPATHLEN + 35];
   char scheme[50], host[MAXPATHLEN], path[MAXPATHLEN];
   char *proxy;
   int port;
   struct hostent *nameinfo;
   int s, rv;
   struct sockaddr_in addr;
   int file_flag = 0;

   if ( strncasecmp(url, "file:", 5) == 0 )
      file_flag = 1;
 
   if ((proxy = getenv("http_proxy")) == NULL || file_flag ) {
      parse_url(url, scheme, host, &port, path);

#ifdef DEBUG
      fprintf(stderr, "URL scheme = %s\n", scheme);
      fprintf(stderr, "URL host = %s\n", host); 
      fprintf(stderr, "URL port = %d\n", port);
      fprintf(stderr, "URL path = %s\n", path);
#endif

      if (strcasecmp(scheme, "http") != 0 && strcasecmp(scheme, "file") != 0) {
         fprintf(stderr, "httpget cannot operate on %s URLs without a proxy\n", scheme);
	 return -1; 
      }
   } 
   else {
      parse_url(proxy, scheme, host, &port, path);
   }

   if ( strcasecmp(scheme, "file") != 0 ) {
      /* Find out the IP address */

      if ((nameinfo = gethostbyname(host)) == NULL) {
         addr.sin_addr.s_addr = inet_addr(host);
	 if ((int)addr.sin_addr.s_addr == -1) {
            fprintf(stderr, "Unknown host %s\n", host);
	    return -2;
	 }
      } 
      else 
         memcpy((char *)&addr.sin_addr.s_addr, nameinfo->h_addr, nameinfo->h_length);

      /* Create socket and connect */
  
      if ((s = socket(PF_INET, SOCK_STREAM, 0)) == -1) {
	 perror("httpget: socket()");
	 return -3; 
      }
      addr.sin_family = AF_INET;
      addr.sin_port = htons(port);
  
      signal(SIGALRM, myhandler);
      alarm(5);
      if (connect(s, (struct sockaddr *)&addr, sizeof(addr)) == -1) {
         alarm(0);
	 if (errno != EINTR) { /* if not just a timeout, print an error */
	    perror("httpget: connect()");
	    }
	 close(s);
	 s = -1;
	 return -4;
      }
      alarm(0);

      if (proxy) {
	 if ( flag == BODY_ONLY ) sprintf(request, "GET %s\r\n", url);
	 else if ( flag == HEADER_ONLY )
            sprintf(request, "HEAD %s HTTP/1.0\r\n", url);
      } 
      else {
	 if ( flag == BODY_ONLY ) sprintf(request, "GET %s\r\n", path);
	 else if ( flag == HEADER_ONLY )
	    sprintf(request, "HEAD %s HTTP/1.0\r\n", path);
      }

      strcat(request, "Accept: */*\r\n\r\n");
  
      write(s, request, strlen(request));

      retval->flag = HTTP_FLAG;
   }
   else {
      if ( (s = open(path, O_RDONLY)) == -1 ) {
         fprintf(stderr, "file open error: %s\n", strerror(errno));	
         return -5;
      }
      retval->flag = FILE_FLAG;	
   }

   retval->s = s; 

   return 0; /* success */
}


/*
 * netopen calls urlopen and change the file descriptor or socket ID into
 * the FILE *.
*/

FILE * netopen(char *url, char *type)
{
   struct netfd temp;
   FILE *fp;
   int retval;

   if ( (retval = urlopen(url, BODY_ONLY, &temp)) < 0 ) {
      fprintf(stderr, "netopen: urlopen(%s) failed with error code: %d\n", url,
		  retval);
      return NULL;
   }

   fp = fdopen(temp.s, type);
   return (fp);
}

/*
 * Open the socket for the host specified in the url using the port specified
 * or using 80 as default. Return FILE * associated with the opened socket ID.
*/

FILE *socketopen(char *url, char *type)
{
   FILE *fp;
   char *host, *colon;
   int port;
   char turl[MAXPATHLEN];
   struct hostent *nameinfo;
   int s;
   struct sockaddr_in addr;
 
   strcpy(turl, url);
 
/* parsing the url to get host name and port number */
 
   if ( (colon = strchr(turl, ':')) != NULL ) {
      *colon = '\0';
      host = colon + 1;
   }
   else {
      fprintf(stderr, "no host name specified\n");
      return NULL;
   }

   if ( (colon = strchr(host, ':')) != NULL ) {
      *colon = '\0';
      port = atoi(colon + 1);
   }
   else 
      port = 80;

/* Find out the IP address */

   if ((nameinfo = gethostbyname(host)) == NULL) {
      addr.sin_addr.s_addr = inet_addr(host);
      if ((int)addr.sin_addr.s_addr == -1) {
         fprintf(stderr, "Unknown host %s\n", host);
         return NULL; 
      }
   }
   else 
      memcpy((char *)&addr.sin_addr.s_addr, nameinfo->h_addr, nameinfo->h_length);
 
 
/* Create socket and connect */
 
   if ((s = socket(PF_INET, SOCK_STREAM, 0)) == -1) {
      perror("httpget: socket()");
      return NULL; 
   }
   addr.sin_family = AF_INET;
   addr.sin_port = htons(port);
 
   if (connect(s, (struct sockaddr *)&addr, sizeof(addr)) == -1) {
      perror("socketopen: connect()");
      return NULL; 
   }
 
   fp = fdopen(s, "r+");
        
   return (fp);
}        


/*
 *  parse the http header information 
*/

void parse_token (char *s, struct http_stat *buf)
{
   char *tmp;

   tmp = strchr(s, ':');

   if (tmp == NULL) {
      return;
      }
   *tmp++ = '\0'; /* past : */
   if (isspace(*tmp)) tmp++; /* past space past : */
   if (tmp[strlen(tmp)-1] == '\015') /* truncate trailing carriage return */
      tmp[strlen(tmp)-1] = '\0';
	
   if ( strcasecmp (s, "server") == 0 ) {
      buf->server = strdup(tmp);
      }
   else if ( strcasecmp(s, "location") == 0 )
      buf->location = strdup(tmp);
   else if ( strcasecmp(s, "content-type") == 0 )
      buf->type = strdup(tmp);
   else if ( strcasecmp(s, "date") == 0 )
      buf->date = strdup(tmp);
   else if ( strcasecmp(s, "last-modified") == 0 )
      buf->last_mod = strdup(tmp);
   else if ( strcasecmp(s, "expires") == 0 )
      buf->exp_date = strdup(tmp);
   else if ( strcasecmp(s, "content-length") == 0 )
      buf->length = atoi(tmp);
   else 
      {};
/*  fprintf(stderr, "This info is not collected: %s\n", s);	*/
}

/* 
 * parsing the status line of the http return header.
*/

void parse_statline ( char *s, struct http_stat *buf)
{
   char *tmp;
   int scode;
	
   tmp = strchr (s, ' ');
   tmp ++;
   scode = atoi (tmp);

   switch ( scode ) {
      case 200:
         buf->scode = OK;
	 break;
      case 201:
	buf->scode = CREATED;   
	break;
      case 202:
         buf->scode = ACCEPTED;
         break;
      case 204:
         buf->scode = NOCONTENT;
         break;
      case 301: 
         buf->scode = MV_PERM;
         break;
      case 302:
         buf->scode = MV_TEMP;
         break;
      case 304:
         buf->scode = NOT_MOD;
         break;
      case 400:
         buf->scode = BAD;
         break;
      case 401:
         buf->scode = UNAUTH;
         break;
      case 403: 
         buf->scode = FORB;
         break;
      case 404:
         buf->scode = NOTFOUND;
         break;
      case 500:
         buf->scode = SERERROR;
         break;
      case 501:
         buf->scode = NOT_IMPL;
         break;
      case 502:
         buf->scode = BADGATE;
         break;
      case 503:	
         buf->scode = UNAVAIL;
         break;
      default:
         printf("Not valid code\n");
         break;
   }
}

/*	
     Upon successful completion a value of 0 is returned.  Other-
     wise, a negative value is returned and errno is set to indicate
     the error. 
*/

int hstat (int sd, struct http_stat *buf )
{
   char temp[BUFLEN+1];
   int  bytes;
   char *str = NULL;
   char *ptr;

   /* initialize buf structure */

   buf->location = NULL;
   buf->server = NULL;
   buf->type = NULL;
   buf->date = NULL;
   buf->last_mod = NULL;
   buf->exp_date = NULL;
   buf->length = 0;

/* read in whole header and store it in a buffer pointed by str. */

   while ((bytes = read(sd, temp, BUFLEN)) != 0) {
      temp[bytes] = '\0';
      if ( str == NULL ) {
         if ( (str = malloc(bytes) ) == NULL ) {
            fprintf(stderr, "malloc fail: %s \n", strerror(errno));
            return -1;
	 }
         strcat (str, temp);
      }
      else {
         if ( (str = realloc (str, strlen(str)+bytes+1) ) == NULL ) {
            fprintf(stderr, "realloc fail: %s \n", strerror(errno));
	    return -2;
	 }
	 strcat (str, temp);
      }
   }

/* parse the buffer pointed by str, line by line using the delimiter '\n' */

   if ( (ptr = strtok (str, "\n") )== NULL ) {
      /* fprintf(stderr, "empty header, %d bytes\n", bytes); */
      return  -3;
   }
   else 
      parse_statline (ptr, buf);

   while ( (ptr = strtok (NULL, "\n")) != NULL )
      parse_token (ptr, buf); 

   free(str);
   return 0;
}

/* 
     Upon successful completion a value of 0 is returned.  Other-
     wise, a value of -1 is returned and errno is set to indicate
     the error. The file status information is saved in the structure
     buf.
*/
 
int netstatus (char *url, struct netstat *buf)
{
   struct netfd temp;
   int retval;
   int rel;

   if ( (rel = urlopen(url, HEADER_ONLY, &temp)) < 0 ) {
      fprintf(stderr, "netstatus: urlopen(%s) failed with return value: %d\n",
		url, rel) ; 
      return -1;
   }

   switch (temp.flag) {
      case FILE_FLAG: 
         buf->flag = FILE_FLAG;
	 retval = fstat (temp.s, &(buf->u.fbuf) );
	 break;	

      case HTTP_FLAG:
         buf->flag = HTTP_FLAG;
	 retval = hstat (temp.s, &(buf->u.hbuf) );
	 break;			
   }

   close (temp.s);
   return retval;
}
#endif					/* Network */

#if NT
#ifdef Dbm
/*
 * Win32 does not provide a link() function expected by GDBM.
 * Cross fingers and hope that copy-on-link semantics will work.
 */
int link(char *s1, char *s2)
{
   int c;
   FILE *f1 = fopen(s1,"rb"), *f2;
   if (f1 == NULL) return -1;
   f2 = fopen(s2, "wb");
   if (f2 == NULL) { fclose(f1); return -1; }
   while ((c = fgetc(f1)) != EOF) fputc(c, f2);
   fclose(f1);
   fclose(f2);
   return 0;
}
#endif					/* Dbm */
#endif					/* NT */

#ifdef NTGCC

/* libc replacement functions for win32.

Copyright (C) 1992, 93 Free Software Foundation, Inc.

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Library General Public
License as published by the Free Software Foundation; either
version 2 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Library General Public License for more details.

You should have received a copy of the GNU Library General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.  */

/*
  This does make sense only under WIN32.
  Functions:
    - popen() rewritten
    - pclose() rewritten
    - stat() wrapper for _stat(), removing trailing slashes
  */

struct _popen_elt {
  FILE *f;                      /* File stream returned */
  HANDLE hp;                    /* Handle of associated process */
  struct _popen_elt *next;      /* Next list element */
};

static struct _popen_elt _z = { NULL, 0, &_z };
static struct _popen_elt *_popen_list = &_z;

FILE *popen (const char* cmd, const char *mode)
{
  STARTUPINFO si;
  PROCESS_INFORMATION pi;
  SECURITY_ATTRIBUTES sa = { sizeof(SECURITY_ATTRIBUTES), NULL, TRUE };
  FILE *f = NULL;
  int fno, i;
  HANDLE child_in, child_out;
  HANDLE father_in, father_out;
  HANDLE father_in_dup, father_out_dup;
  HANDLE current_in, current_out;
  HANDLE current_pid;
  int binary_mode;
  char *new_cmd, *app_name = NULL;
  char *p, *q;
  struct _popen_elt *new_process;
  char pname[PATH_MAX], *fp;
  char *suffixes[] = { ".bat", ".cmd", ".com", ".exe", NULL };
  char **s;
  int go_on;

  /*
   * Look for the application name along the PATH,
   * and decide to prepend "%COMSPEC% /c " or not to the command line.
   * Do nothing for the moment.
   */

  /* Another way to do that would be to try CreateProcess first without
     invoking cmd, and look at the error code. If it fails because of
     command not found, try to prepend "cmd /c" to the cmd line.
     */

  /* Look for the application name */
  for (p = cmd; *p && isspace(*p); p++);
  if (*p == '"') {
    q = ++p;
    while(*p && *p != '"') p++;
    if (*p != '\0') {
      fprintf(stderr, "popen: malformed command (\" not terminated)\n");
      return NULL;
    }
  }
  else
    for (q = p; *p && !isspace(*p); p++);
  /* q points to the beginning of appname, p to the last + 1 char */
  if ((app_name = malloc(p - q + 1)) == NULL) {
    fprintf(stderr, "xpopen: malloc(app_name) failed.\n");
    return NULL;
  }
  strncpy(app_name, q, p - q );
  app_name[p - q] = '\0';
  pname[0] = '\0';
#ifdef __TRACE
  fprintf(stderr, "popen: app_name = %s\n", app_name);
#endif

  /* Looking for appname on the path */
  for (s = suffixes, go_on = 1; go_on; *s++) {
    if (SearchPath(NULL,        /* Address of search path */
                   app_name,    /* Address of filename */
                   *s,          /* Address of extension */
                   PATH_MAX,    /* Size of destination buffer */
                   pname,       /* Address of destination buffer */
                   &fp)         /* File part of app_name */
      != 0) {
#ifdef __TRACE
      fprintf(stderr, "%s found with suffix %s\n", app_name, *s);
#endif
      new_cmd = strdup(cmd);
      free(app_name);
      app_name = strdup(pname);
      break;
    }
    go_on = (*s != NULL);
  }
  if (go_on == 0) {
    /* the app_name was not found */
#ifdef __TRACE
    fprintf(stderr, "%s not found, concatenating comspec\n", app_name);
#endif
    new_cmd = malloc(strlen(getenv("CONSPEC"))+4+strlen(cmd)+1);
    sprintf(new_cmd, "%s /c %s", getenv("COMSPEC"), cmd);
    free(app_name);
    app_name = NULL;
  }
  else {
  }
#ifdef __TRACE
  fprintf(stderr, "popen: app_name = %s\n", app_name);
  fprintf(stderr, "popen: cmd_line = %s\n", new_cmd);
#endif

  current_in = GetStdHandle(STD_INPUT_HANDLE);
  current_out = GetStdHandle(STD_OUTPUT_HANDLE);
  current_pid = GetCurrentProcess();
  ZeroMemory( &si, sizeof(STARTUPINFO) );
  si.cb = sizeof(STARTUPINFO);
  si.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
  si.wShowWindow = SW_HIDE;

  if (strchr(mode, 'b'))
    binary_mode = _O_BINARY;
  else
    binary_mode = _O_TEXT;

  /* Opening the pipe for writing */
  if (strchr(mode, 'w')) {
    binary_mode |= _O_WRONLY;
    if (CreatePipe(&child_in, &father_out, &sa, 0) == FALSE) {
      fprintf(stderr, "popen: error CreatePipe\n");
      return NULL;
    }
#if 0
    if (SetStdHandle(STD_INPUT_HANDLE, child_in) == FALSE) {
      fprintf(stderr, "popen: error SetStdHandle child_in\n");
      return NULL;
    }
#endif
    si.hStdInput = child_in;
    si.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
    si.hStdError = GetStdHandle(STD_ERROR_HANDLE);

    if (DuplicateHandle(current_pid, father_out, 
                        current_pid, &father_out_dup, 
                        0, FALSE, DUPLICATE_SAME_ACCESS) == FALSE) {
      fprintf(stderr, "popen: error DuplicateHandle father_out\n");
      return NULL;
    }
    CloseHandle(father_out);
    fno = _open_osfhandle((long)father_out_dup, binary_mode);
    f = _fdopen(fno, mode);
    i = setvbuf( f, NULL, _IONBF, 0 );
  }
  /* Opening the pipe for reading */
  else if (strchr(mode, 'r')) {
    binary_mode |= _O_RDONLY;
    if (CreatePipe(&father_in, &child_out, &sa, 0) == FALSE) {
      fprintf(stderr, "popen: error CreatePipe\n");
      return NULL;
    }
#if 0
    if (SetStdHandle(STD_OUTPUT_HANDLE, child_out) == FALSE) {
      fprintf(stderr, "popen: error SetStdHandle child_out\n");
      return NULL;
    }
#endif
    si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
    si.hStdOutput = child_out;
    si.hStdError = GetStdHandle(STD_ERROR_HANDLE);
    if (DuplicateHandle(current_pid, father_in, 
                        current_pid, &father_in_dup, 
                        0, FALSE, DUPLICATE_SAME_ACCESS) == FALSE) {
      fprintf(stderr, "popen: error DuplicateHandle father_in\n");
      return NULL;
    }
    CloseHandle(father_in);
    fno = _open_osfhandle((long)father_in_dup, binary_mode);
    f = _fdopen(fno, mode);
    i = setvbuf( f, NULL, _IONBF, 0 );
  }
  else {
    fprintf(stderr, "popen: invalid mode %s\n", mode);
    return NULL;
  }

  /* creating child process */
  if (CreateProcess(app_name,   /* pointer to name of executable module */
                    new_cmd,    /* pointer to command line string */
                    NULL,       /* pointer to process security attributes */
                    NULL,       /* pointer to thread security attributes */
                    TRUE,       /* handle inheritance flag */
                    CREATE_NEW_CONSOLE,         /* creation flags */
                    NULL,       /* pointer to environment */
                    NULL,       /* pointer to current directory */
                    &si,        /* pointer to STARTUPINFO */
                    &pi         /* pointer to PROCESS_INFORMATION */
                  ) == FALSE) {
    fprintf(stderr, "popen: CreateProcess %x\n", GetLastError());
    return NULL;
  }
  
#if 0
  /* Restoring saved values for stdin/stdout */
  if (SetStdHandle(STD_INPUT_HANDLE, current_in) == FALSE) 
    fprintf(stderr, "popen: error re-redirecting Stdin\n");  
  if (SetStdHandle(STD_OUTPUT_HANDLE, current_out) == FALSE) 
    fprintf(stderr, "popen: error re-redirecting Stdout\n");  
#endif  
   /* Only the process handle is needed */
  if (CloseHandle(pi.hThread) == FALSE) {
    fprintf(stderr, "popen: error closing thread handle\n");
    return NULL;
  }

  if (new_cmd) free(new_cmd);
  if (app_name) free(app_name);

#if 0
  /* This does not seem to make sense for console apps */
  while (1) {
    i = WaitForInputIdle(pi.hProcess, 5); /* Wait 5ms  */
    if (i == 0xFFFFFFFF) {
      fprintf(stderr, "popen: process can't initialize\n");
      return NULL;
    }
    else if (i == WAIT_TIMEOUT)
      fprintf(stderr, "popen: warning, process still not initialized\n");
    else
      break;
  }
#endif

  /* Add the pair (f, pi.hProcess) to the list */
  if ((new_process = malloc(sizeof(struct _popen_elt))) == NULL) {
    fprintf (stderr, "popen: malloc(new_process) error\n");
    return NULL;
  }
  /* Saving the FILE * pointer, access key for retrieving the process
     handle later on */
  new_process->f = f;
  /* Closing the unnecessary part of the pipe */
  if (strchr(mode, 'r')) {
    CloseHandle(child_out);
  }
  else if (strchr(mode, 'w')) {
    CloseHandle(child_in);
  }
  /* Saving the process handle */
  new_process->hp = pi.hProcess;
  /* Linking it to the list of popen() processes */
  new_process->next = _popen_list;
  _popen_list = new_process;

  return f;

}

int pclose (FILE * f)
/* [<][>][^][v][top][bottom][index][help] */
{
  struct _popen_elt *p, *q;
  int exit_code;

  /* Look for f is the access key in the linked list */
  for (q = NULL, p = _popen_list; 
       p != &_z && p->f != f; 
       q = p, p = p->next);

  if (p == &_z) {
    fprintf(stderr, "pclose: error, file not found.");
    return -1;
  }

  /* Closing the FILE pointer */
  fclose(f);

  /* Waiting for the process to terminate */
  if (WaitForSingleObject(p->hp, INFINITE) != WAIT_OBJECT_0) {
    fprintf(stderr, "pclose: error, process still active\n");
    return -1;
  }

  /* retrieving the exit code */
  if (GetExitCodeProcess(p->hp, &exit_code) == 0) {
    fprintf(stderr, "pclose: can't get process exit code\n");
    return -1;
  }

  /* Closing the process handle, this will cause the system to
     remove the process from memory */
  if (CloseHandle(p->hp) == FALSE) {
    fprintf(stderr, "pclose: error closing process handle\n");
    return -1;
  }

  /* remove the elt from the list */
  if (q != NULL)
    q->next = p->next;
  else
    _popen_list = p->next;
  free(p);
    
  return exit_code;
}
#endif

#ifdef PseudoPty

struct ptstruct
{
#ifdef WIN32
   HANDLE master_read, master_write;
   HANDLE slave_pid;
#else					/* WIN32 */
  int master_fd, slave_fd;		/* master, slave pty file descriptor */
  pid_t slave_pid;			/* process id of slave  */
#endif					/* WIN32 */
     
  char slave_filename[256]; /* pty slave filename associated with master pty */
  char slave_command[256]; /* name of executable associated with slave */
};

void ptclose(struct ptstruct *ptStruct)
{
   int close_ret, status;
   if (ptStruct == NULL)
      return;  /* structure is NULL, nothing to do */

#ifdef WIN32
   close_ret=CloseHandle(ptStruct->master_read);
   close_ret=CloseHandle(ptStruct->master_write);
#else					/* WIN32 */
   /* close the master and slave file descriptors */
   close_ret = close(ptStruct->master_fd);
   close_ret = close(ptStruct->slave_fd);
   /* terminate the child process */
   waitpid(ptStruct->slave_pid,&status,WNOHANG);
   kill(ptStruct->slave_pid,SIGKILL);
#endif					/* WIN32 */
   /* free the space allocated for the structure */
   free(ptStruct);
   return;
}

#define EXITERROR(P) { ptclose(P); return NULL; }

struct ptstruct *ptopen(char *command)
{

#ifdef WIN32
   HANDLE hOutputReadMaster,hOutputRead,hOutputWrite;
   HANDLE hInputWriteMaster,hInputRead,hInputWrite;
   HANDLE hIOTmp;
   HANDLE hStdIn = NULL;
   SECURITY_ATTRIBUTES sa;
   PROCESS_INFORMATION pi;
   STARTUPINFO si;
#else
   int pstatus;
#endif

   /* allocating new ptstruct */
   struct ptstruct *newPtStruct =
      (struct ptstruct *)malloc(sizeof(struct ptstruct));
   if(newPtStruct == NULL) {
      EXITERROR(newPtStruct);
      }

#ifdef WIN32
   /* Set up the security attributes struct. */
   sa.nLength= sizeof(SECURITY_ATTRIBUTES);
   sa.lpSecurityDescriptor = NULL;
   sa.bInheritHandle = TRUE;

   /* Create the child output pipe */
   if(!CreatePipe(&newPtStruct->master_read,&hOutputWrite,&sa,0)) {
      EXITERROR(newPtStruct);
      }

   if (!CreatePipe(&hInputRead,&newPtStruct->master_write,&sa,0)) {
      EXITERROR(newPtStruct);
      }

   /* Set up the start up info struct. */
   ZeroMemory(&si,sizeof(STARTUPINFO));
   si.cb = sizeof(STARTUPINFO);
   si.dwFlags = STARTF_USESTDHANDLES;
   si.hStdOutput = hOutputWrite;
   si.hStdInput  = hInputRead;
   si.hStdError  = hOutputWrite;

   /* Launch the process that you want to redirect */
   if (!CreateProcess(NULL,newPtStruct->slave_command,NULL,NULL,TRUE,
		      CREATE_NEW_CONSOLE,NULL,NULL,&si,&pi)) {
      EXITERROR(newPtStruct);
      }

   /* Set global child process handle to cause threads to exit. */
   newPtStruct->slave_pid = pi.hProcess;

#else

  /* open master pty file descriptor */
#ifdef SOLARIS
   if((newPtStruct->master_fd=open("/dev/ptmx",O_RDWR|O_NONBLOCK)) == -1) {
      EXITERROR(newPtStruct);
      }
#else
   if((newPtStruct->master_fd=posix_openpt(O_RDWR|O_NONBLOCK)) == -1) {
      EXITERROR(newPtStruct);
      }
#endif

   /* change permissions of slave pty to correspond with the master pty */
   if(grantpt(newPtStruct->master_fd) == -1) {
      EXITERROR(newPtStruct);
      }

   /* unlock the slave pty file descriptor before opening it */
   if(unlockpt(newPtStruct->master_fd) == -1) {
      EXITERROR(newPtStruct);
      }

   /*
    * determine the filename of the slave pty associated with
    * the already opened master pty
    */
#ifdef SOLARIS
   if(ttyname_r(newPtStruct->master_fd,newPtStruct->slave_filename,
	              sizeof(newPtStruct->slave_filename)) != 0) {
#else
   if(ptsname_r(newPtStruct->master_fd,newPtStruct->slave_filename,
		sizeof(newPtStruct->slave_filename)) != 0) {
#endif
      EXITERROR(newPtStruct);
      }

   /* finally open the slave pty file descriptor */
   if((newPtStruct->slave_fd=open(newPtStruct->slave_filename,
				  O_RDWR|O_NONBLOCK)) == -1) {
      EXITERROR(newPtStruct);
      }

   strcpy(newPtStruct->slave_command, command);
  
   /* try forking the slave process ... */
   if ((newPtStruct->slave_pid = fork()) == -1) {
      EXITERROR(newPtStruct);
      }
   else if(newPtStruct->slave_pid == 0) {
      /* create a session id and make this process the process group leader */
      if(setsid() == -1) /* was setpgid */
	 EXITERROR(newPtStruct);
      /*
       * dup standard file descriptors to be associated with pseudo terminal */
      if(dup2(newPtStruct->slave_fd,0) == -1) {
	 EXITERROR(newPtStruct);
	 }
      if(dup2(newPtStruct->slave_fd,1) == -1) {
	 EXITERROR(newPtStruct);
	 }
      if(dup2(newPtStruct->slave_fd,2) == -1) {
	 EXITERROR(newPtStruct);
	 }

      /* attempt to execute the command slave process */
      {
	 char *args[2]={newPtStruct->slave_command, NULL};
	 if(execve(args[0],(char *const*)args,0) == -1) {
	    EXITERROR(newPtStruct);
	    }
	 }
#endif
      }

  return newPtStruct;
#undef EXITERROR

}


int ptgetstrt(char *buffer, const int bufsiz, struct ptstruct *ptStruct, unsigned long waittime, int longread)
   {
   int bytes_read=0, tot_bytes_read=0, wait_fd, i=0, ret=0, premstop=0;
#ifndef WIN32
   fd_set rd_set;
   struct timeval timeout, *timeoutp = NULL;
#endif

   if(buffer == NULL || ptStruct == NULL)
      return -1;

#ifndef WIN32
  
   /* clear the buffer */
   memset(buffer,0,sizeof(buffer));

   if (!longread) {
      timeout.tv_sec  = 0L;
      timeout.tv_usec = waittime;
      timeoutp = &timeout;
      }

   /* set the wait file descriptor for use with select */
   wait_fd = ptStruct->master_fd+1;
  
   /* set file descriptor sets for reading with select */
   FD_ZERO(&rd_set);
   if (ptStruct->master_fd > -1) {
      FD_SET(ptStruct->master_fd,&rd_set);
      }
   else
      return -1;

  /*
   * if select returns without any errors and
   * if the characters are available to read from input ...
   */
#endif /* WIN32 */

#ifdef WIN32
   /* clear the buffer */
   ZeroMemory(buffer,bufsiz);
   if(WaitForSingleObject(ptStruct->master_read,waittime) != WAIT_FAILED) {
#else


   if((ret=select(wait_fd,&rd_set,NULL,NULL,timeoutp)) > 0
      && FD_ISSET(ptStruct->master_fd,&rd_set) ) {

#endif /* WIN32 */

    while(!premstop && tot_bytes_read < bufsiz 

#ifdef WIN32
	  && (ret=ReadFile(ptStruct->master_read,&buffer[i],1,
			   &bytes_read,NULL)) != 0) {
#else
       && (bytes_read=read(ptStruct->master_fd,&buffer[i],1)) > 0) {
#endif // WIN32
	     if(!longread && buffer[i] == '\n') {
		if (buffer[i-1] == '\r') tot_bytes_read--;
		premstop=1;
		}
	     tot_bytes_read += bytes_read;
      i++;

#ifdef WIN32
#else
      FD_ZERO(&rd_set);
      FD_SET(ptStruct->master_fd,&rd_set);
#endif // WIN32

       }
       }

#ifdef WIN32
      else ret = -1;
      if (ret == 0)
	 ret = -1;
#else
else {
   }
#endif					/* WIN32 */


   /* if some bytes were read than return the number read */
   if (tot_bytes_read > 0) {
      if(!longread && premstop) tot_bytes_read--;
      return tot_bytes_read;
      }
  /* else if no bytes were read at all than return an error code */
   else if (tot_bytes_read == 0) {
      return -1;
      }
   /* else return the value returned by select */
   return ret;
   }

int ptgetstr(char *buffer, const int bufsiz, struct ptstruct *ptStruct, struct timeval *timeout)
{
   return ptgetstrt(buffer, bufsiz, ptStruct, 10000000, 0);
#if 0
  presumably subsumed above
  fd_set rd_set;
  int bytes_read=0, ret=0, wait_fd, i=0, sel_ret;

  if(buffer == NULL | ptStruct == NULL | timeout == NULL)
    return -1;
  
  /* set the wait file descriptor for use with select */
  wait_fd = ptStruct->master_fd+1;
 
  /* clear the buffer */
  memset(buffer,0,sizeof(buffer));
  
  /* set file descriptor sets for reading with select */
  FD_ZERO(&rd_set);
  if(ptStruct->master_fd > -1)
    FD_SET(ptStruct->master_fd,&rd_set);
  else
    return -1;
  /* if select returns without any errors then ... */
  /* if the characters are availabe to read from input ... */
  while((sel_ret=select(wait_fd,&rd_set,NULL,NULL,timeout)) > 0
	&& FD_ISSET(ptStruct->master_fd,&rd_set)
	&& bytes_read < bufsiz 
	&& (ret=read(ptStruct->master_fd,&buffer[i],1)) > 0) {
	bytes_read += ret;
	i++;
	FD_ZERO(&rd_set);
	FD_SET(ptStruct->master_fd,&rd_set);
  } 
  if(bytes_read > 0) {
    /* printf("output: %s",buffer); */
    return bytes_read;
  } else if(bytes_read == 0 && !FD_ISSET(ptStruct->master_fd,&rd_set)) {
    return -1;
  }
  return sel_ret;
#endif
}

int ptlongread(char *buffer, const int nelem, struct ptstruct *ptStruct)
{
   return ptgetstrt(buffer, nelem, ptStruct, 0, 1);
#if 0
  fd_set rd_set;
  int bytes_read=0, ret=0, wait_fd, i=0;
  
  /*   size_t max_read_bytes=sizeof(char)*256; */
  /* if ptystruct pointer is NULL than return with error code */
  if(ptStruct == NULL)
    return -1;
  
  /* set the wait file descriptor for use with select */
  wait_fd = ptStruct->master_fd+1;

  /* clear the buffer */
  memset(buffer,0,sizeof(buffer));
  
  /* set file descriptor sets for reading with select */
  FD_ZERO(&rd_set);
  if(ptStruct->master_fd > -1) 
    FD_SET(ptStruct->master_fd,&rd_set);
   
  /* if select returns without any errors then ... */
  if(select(wait_fd,&rd_set,NULL,NULL,NULL) > 0) {
    /* if the characters are availabe to read from input ... */
    if(FD_ISSET(ptStruct->master_fd,&rd_set)) {
      /* read all the characters until  */
      /* 1) none are available */
      /* 2) the maximum buffer size has been reached */
      /* 3) a newline has been read */
      while((ret=read(ptStruct->master_fd,&buffer[i],1)) > 0 
	    && (bytes_read+=ret) < nelem) 
	i++;

      /* if there was an error then return an error code */
      if( ret < 0)
	ret = -1; /* -1 indicates error reading from slave */
      else 
	ret = bytes_read;
    } else {
      /* select timed out */
      ret = -2;
    }
  } else 
    ret = -1; /* error occurred from select */
  return ret;
#endif
}

int ptputstr(struct ptstruct *ptStruct, char *buffer, int bufsize)
{
   int bytes_written, ret=0, pstatus, sel_ret;

   if (ptStruct == NULL || buffer == NULL || bufsize < 1)
      return -1;

#ifdef WIN32
   if ( (WaitForSingleObject(ptStruct->master_write,0) == WAIT_FAILED) ||
       (!WriteFile(ptStruct->master_write,buffer,bufsize,&bytes_written,NULL)))
      ret = -1;
   else 
      ret = bytes_written;
#else					/* WIN32 */

   {
   fd_set wd_set;
   struct timeval timeout;

   timeout.tv_sec=0L;
   timeout.tv_usec=0L;
  
   /* set file descriptors for writing with select */
   FD_ZERO(&wd_set);
   if(ptStruct->master_fd > -1) 
      FD_SET(ptStruct->master_fd,&wd_set);
   else
      return -3; /* invalid output file descriptor - return error */

   if ((sel_ret=select(ptStruct->master_fd+1,NULL,&wd_set,NULL,&timeout)) > 0){
      /* if the file descriptor is ready to write to ... */
      if(FD_ISSET(ptStruct->master_fd,&wd_set)) {
	 if((bytes_written=write(ptStruct->master_fd,buffer,bufsize)) < 0) 
	    ret = -1; /* -1 indicates error writing to file descriptor */
	 else 
	    ret=bytes_written;
	 }
      else {
	 /* select timed out */
	 ret = 0; /* was -2 */
	 }
      }
   else {
      ret = sel_ret; /* return value returned by select */
      }
   }

#endif					/* WIN32 */
  return ret;
}

int ptputc(const char c, struct ptstruct *ptStruct)
{
   return ptputstr(ptStruct, &c, 1);
}

int ptflush(struct ptstruct *ptStruct)
{
#if 0
   /* not implemented; not sure if this gobbledy gook does anything */
  fd_set rd_set;
  char temp_read;
  int wait_fd = ptStruct->slave_fd+1;
  FD_ZERO(&rd_set);
  FD_SET(ptStruct->slave_fd,&rd_set);
  if(select(wait_fd,&rd_set,NULL,NULL,NULL) > 0) {
    if(FD_ISSET(ptStruct->slave_fd,&rd_set)) {
      while(read(ptStruct->slave_fd,&temp_read,sizeof(temp_read)) > 0);
      return 0;
    } else {
      return -2;
    }
  }
#endif
  return -1;
}

#endif					/* PseudoPty */
