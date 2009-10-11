#import "XeeInterleavingHandle.h"
#import "XeeTypes.h"

static void transpose8(uint8_t *buf,int n1,int n2);
static void transpose16(uint16_t *buf,int n1,int n2);
static void transpose32(uint32_t *buf,int n1,int n2);
static int factor(int n,int *ifact,int *ipower,int *nexp);

#ifndef TEST

@implementation XeeInterleavingHandle

-(id)initWithHandles:(NSArray *)handlearray elementSize:(int)bitsize;
{
	if(self=[super initWithName:[[handlearray objectAtIndex:0] name]])
	{
		handles=[handlearray retain];
		n2=[handles count];
		bits=bitsize;
	}
	return self;
}

-(void)dealloc
{
	[handles release];
	[super dealloc];
}

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	if(!num) return 0;

	int entrybytes=bits/8;
	int pixelbytes=entrybytes*n2;
	int channelbytes=num/n2;

	if(num%pixelbytes!=0) [self _raiseNotSupported:_cmd];
	int n1=num/pixelbytes;

	uint8_t *buf=(uint8_t *)buffer;
	int minbytes=channelbytes;

	for(int i=0;i<n2;i++)
	{
		int bytes=[[handles objectAtIndex:i] readAtMost:channelbytes toBuffer:buf+i*channelbytes];
		if(bytes<minbytes) minbytes=bytes;
	}
	if(n1==1||n2==1) return n2*minbytes;

	switch(bits)
	{
		case 8: transpose8(buffer,n1,n2); break;
		case 16: transpose16(buffer,n1,n2); break;
		case 32: transpose32(buffer,n1,n2); break;
	}

	return n2*minbytes;
}

@end

#endif

#ifdef TEST

#import <stdio.h>
#import <stdlib.h>

void test(int n1,int n2)
{
	uint8_t m[n1*n2];

	for(int i=0;i<n1*n2;i++) m[i]=i;

	transpose(m,n1,n2);

	for(int i=0;i<n1*n2-1;i++)
	{
		if(m[(i*n2)%(n1*n2-1)]!=(uint8_t)i) { printf("Error\n"); exit(1); }
	}

	printf("Ok!\n");
}
int main()
{
	for(int n1=2;n1<100;n1++)
	for(int n2=2;n2<100;n2++)
	{
		if(n1==2&&n2==2) continue;
		printf("%d,%d: ",n1,n2);
		test(n1,n2);
	}

	return 0;
}

#endif


static void transpose8(uint8_t *buf,int n1,int n2)
{
	int n=n1,m=n1*n2-1;
	int ifact[10],ipower[10],nexp[10];
	int npower=factor(m,ifact,ipower,nexp);
	int iexp[10]={0,0,0,0,0,0,0,0,0,0};
	int idiv=1;

	label50:
	if(idiv>=m/2) return;

	int ncount=m/idiv;
	for(int i=0;i<npower;i++) if(iexp[i]!=nexp[i]) ncount=(ncount/ifact[i])*(ifact[i]-1);

	int istart=idiv;
	while(ncount>0)
	{
		int mmist=m-istart;
		if(istart!=idiv)
		{
			int isoid=istart/idiv;
			for(int i=0;i<npower;i++) if(iexp[i]!=nexp[i]&&isoid%ifact[i]==0) goto label160;
			int itest=istart;
			do {
				itest=(n*itest)%m;
				if(itest<istart||itest>mmist) goto label160;
			} while(itest>istart&&itest<mmist);
		}

		uint32_t atemp=buf[istart],btemp=buf[mmist];
		int ia1=istart;
		for(;;)
		{
			int ia2=(n*ia1)%m;
			int mmia1=m-ia1,mmia2=m-ia2;
			ncount-=2;

			if(ia2==istart) { buf[ia1]=atemp; buf[mmia1]=btemp; break; }
			if(mmia2==istart) { buf[ia1]=btemp; buf[mmia1]=atemp; break; }
			buf[ia1]=buf[ia2];
			buf[mmia1]=buf[mmia2];
			ia1=ia2;
		}

		label160:
		istart+=idiv;
	}

	for(int i=0;i<npower;i++)
	{
		if(iexp[i]!=nexp[i])
		{
			iexp[i]++;
			idiv*=ifact[i];
			goto label50;
		}
		iexp[i]=0;
		idiv/=ipower[i];
	}
}

static void transpose16(uint16_t *buf,int n1,int n2)
{
	int n=n1,m=n1*n2-1;
	int ifact[10],ipower[10],nexp[10];
	int npower=factor(m,ifact,ipower,nexp);
	int iexp[10]={0,0,0,0,0,0,0,0,0,0};
	int idiv=1;

	label50:
	if(idiv>=m/2) return;

	int ncount=m/idiv;
	for(int i=0;i<npower;i++) if(iexp[i]!=nexp[i]) ncount=(ncount/ifact[i])*(ifact[i]-1);

	int istart=idiv;
	while(ncount>0)
	{
		int mmist=m-istart;
		if(istart!=idiv)
		{
			int isoid=istart/idiv;
			for(int i=0;i<npower;i++) if(iexp[i]!=nexp[i]&&isoid%ifact[i]==0) goto label160;
			int itest=istart;
			do {
				itest=(n*itest)%m;
				if(itest<istart||itest>mmist) goto label160;
			} while(itest>istart&&itest<mmist);
		}

		uint32_t atemp=buf[istart],btemp=buf[mmist];
		int ia1=istart;
		for(;;)
		{
			int ia2=(n*ia1)%m;
			int mmia1=m-ia1,mmia2=m-ia2;
			ncount-=2;

			if(ia2==istart) { buf[ia1]=atemp; buf[mmia1]=btemp; break; }
			if(mmia2==istart) { buf[ia1]=btemp; buf[mmia1]=atemp; break; }
			buf[ia1]=buf[ia2];
			buf[mmia1]=buf[mmia2];
			ia1=ia2;
		}

		label160:
		istart+=idiv;
	}

	for(int i=0;i<npower;i++)
	{
		if(iexp[i]!=nexp[i])
		{
			iexp[i]++;
			idiv*=ifact[i];
			goto label50;
		}
		iexp[i]=0;
		idiv/=ipower[i];
	}
}

static void transpose32(uint32_t *buf,int n1,int n2)
{
	int n=n1,m=n1*n2-1;
	int ifact[10],ipower[10],nexp[10];
	int npower=factor(m,ifact,ipower,nexp);
	int iexp[10]={0,0,0,0,0,0,0,0,0,0};
	int idiv=1;

	label50:
	if(idiv>=m/2) return;

	int ncount=m/idiv;
	for(int i=0;i<npower;i++) if(iexp[i]!=nexp[i]) ncount=(ncount/ifact[i])*(ifact[i]-1);

	int istart=idiv;
	while(ncount>0)
	{
		int mmist=m-istart;
		if(istart!=idiv)
		{
			int isoid=istart/idiv;
			for(int i=0;i<npower;i++) if(iexp[i]!=nexp[i]&&isoid%ifact[i]==0) goto label160;
			int itest=istart;
			do {
				itest=(n*itest)%m;
				if(itest<istart||itest>mmist) goto label160;
			} while(itest>istart&&itest<mmist);
		}

		uint32_t atemp=buf[istart],btemp=buf[mmist];
		int ia1=istart;
		for(;;)
		{
			int ia2=(n*ia1)%m;
			int mmia1=m-ia1,mmia2=m-ia2;
			ncount-=2;

			if(ia2==istart) { buf[ia1]=atemp; buf[mmia1]=btemp; break; }
			if(mmia2==istart) { buf[ia1]=btemp; buf[mmia1]=atemp; break; }
			buf[ia1]=buf[ia2];
			buf[mmia1]=buf[mmia2];
			ia1=ia2;
		}

		label160:
		istart+=idiv;
	}

	for(int i=0;i<npower;i++)
	{
		if(iexp[i]!=nexp[i])
		{
			iexp[i]++;
			idiv*=ifact[i];
			goto label50;
		}
		iexp[i]=0;
		idiv/=ipower[i];
	}
}

static int factor(int n,int *ifact,int *ipower,int *nexp)
{
	int i=-1;
	int ifcur=0;
	int npart=n;
	int idiv=2;

	for(;;)
	{
		int iquot=npart/idiv;
		if(npart==idiv*iquot)
		{
			if(idiv>ifcur)
			{
				i++;
				ifact[i]=ipower[i]=idiv;
				ifcur=idiv;
				nexp[i]=1;
			}
			else
			{
				ipower[i]*=idiv;
				nexp[i]++;
			}
			npart=iquot;
		}
		else
		{
			if(iquot>idiv)
			{
				if(idiv<=2) idiv=3;
				else idiv+=2;
			}
			else
			{
				if(npart>1)
				{
					if(npart>ifcur)
					{
						i++;
						ifact[i]=ipower[i]=npart;
						nexp[i]=1;
					}
					else
					{
						ipower[i]*=npart;
						nexp[i]++;
					}
				}
				return i+1;
			}
		}
	}
}

/*
static void transpose(uint8_t *buf,int n1,int n2)
{
	int n=n1;
	int m=n1*n2-1;

	//int nwork=(n1+n2)/2+1;
	//BOOL moved[nwork];
	//for(int i=0;i<nwork;i++) moved[i]=NO;

	int ifact[10],ipower[10],nexp[10];
	int npower=factor(m,ifact,ipower,nexp);
	int iexp[10]={0,0,0,0,0,0,0,0,0,0};

	int idiv=1;

	label50:
	if(idiv>=m/2) return;

	// the number of elements whose index is divisible by idiv and by no other
	// divisor of m is the Euler totient function, phi(m/idiv)
	int ncount=m/idiv;
	for(int i=0;i<npower;i++)
	{
		if(iexp[i]!=nexp[i]) ncount=(ncount/ifact[i])*(ifact[i]-1);
	}

	// the starting point of a subcycle is divisible only by idiv and must not
	// appear in any other subcycle

	int istart=idiv;

	while(ncount>0)
	{
		int mmist=m-istart;

		if(istart!=idiv)
		{
			//if(istart<nwork&&moved[istart]) goto label160;

			int isoid=istart/idiv;
			for(int i=0;i<npower;i++)
			{
				if(iexp[i]!=nexp[i]&&isoid%ifact[i]==0) goto label160;
			}

			//if(istart>=nwork)
			{
				int itest=istart;
				do {
					itest=(n*itest)%m;
					if(itest<istart||itest>mmist) goto label160;
				} while(itest>istart&&itest<mmist);
			}
		}

		int atemp=buf[istart];
		int btemp=buf[mmist];
		int ia1=istart;
		for(;;)
		{
			int ia2=(n*ia1)%m;

			int mmia1=m-ia1;
			int mmia2=m-ia2;
			//if(ia1<nwork) moved[ia1]=YES;
			//if(mmia1<nwork) moved[mmia1]=YES;
			ncount-=2;

			// move two elements, the second from the negative subcycle.
			// check first for subcycle closure.
			if(ia2==istart)
			{
				buf[ia1]=atemp;
				buf[mmia1]=btemp;
				break;
			}
			if(mmia2==istart)
			{
				buf[ia1]=btemp;
				buf[mmia1]=atemp;
				break;
			}
			buf[ia1]=buf[ia2];
			buf[mmia1]=buf[mmia2];
			ia1=ia2;
		}

		label160:
		istart+=idiv;
	}

	for(int i=0;i<npower;i++)
	{
		if(iexp[i]!=nexp[i])
		{
			iexp[i]++;
			idiv*=ifact[i];
			goto label50;
		}
		iexp[i]=0;
		idiv/=ipower[i];
	}
}
*/