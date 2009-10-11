#import "XeeJPEGQuantizationDatabase.h"
#import "XeeProperties.h"
#import "XeeTypes.h"


@implementation XeeJPEGQuantizationDatabase

+(XeeJPEGQuantizationDatabase *)defaultDatabase
{
	static XeeJPEGQuantizationDatabase *database=nil;

	if(!database) database=[[XeeJPEGQuantizationDatabase alloc]
	initWithFile:[[NSBundle mainBundle] pathForResource:@"jpeg_quant" ofType:@"txt"]];

	return database;
}

-(id)initWithFile:(NSString *)filename
{
	if(self=[super init])
	{
		dict=[[NSMutableDictionary dictionary] retain];

		FILE *fh=fopen([filename fileSystemRepresentation],"r");
		if(fh)
		{
			char buf[4096];
			while(fgets(buf,sizeof(buf),fh))
			{
				if(buf[0]=='#') continue;
				char *colon=strchr(buf,':');
				if(!colon) continue;
				char *end=strchr(buf,'\n');
				if(end) *end=0;

				*colon=0;
				NSString *label=[NSString stringWithUTF8String:buf];

				char *start=colon+1;
				while(*start&&*start==' ') start++;
				NSString *table=[NSString stringWithUTF8String:start];

				NSMutableArray *array=[dict objectForKey:table];
				if(!array) [dict setObject:array=[NSMutableArray array] forKey:table];
				[array addObject:label];

				char *stop=start;
				for(int i=0;i<64&&stop;i++) stop=strchr(stop+1,' ');

				if(stop)
				{
					*stop=0;
					NSString *shorttable=[NSString stringWithUTF8String:start];
					NSMutableArray *array=[dict objectForKey:shorttable];
					if(!array) [dict setObject:array=[NSMutableArray array] forKey:shorttable];
					[array addObject:label];
				}

				// make single-channel, transposed versions!
			}
		}
	}

	return self;
}

-(void)dealloc
{
	[dict release];
	[super dealloc];
}

-(NSArray *)producersForTables:(struct jpeg_decompress_struct *)cinfo
{
	int num_quant_tables;
	for(num_quant_tables=0;num_quant_tables<NUM_QUANT_TBLS&&cinfo->quant_tbl_ptrs[num_quant_tables];num_quant_tables++);

	if(num_quant_tables==3&&cinfo->jpeg_color_space==JCS_YCbCr)
	{
		BOOL dupe_table=YES;
		for(int i=0;i<64&&dupe_table;i++)
		if(cinfo->quant_tbl_ptrs[1]->quantval[i]!=cinfo->quant_tbl_ptrs[2]->quantval[i]) dupe_table=NO;

		if(dupe_table) num_quant_tables--;
	}

	NSMutableString *tables=[NSMutableString string];
	for(int i=0;i<num_quant_tables;i++)
	for(int j=0;j<64;j++)
	[tables appendFormat:@"%s%d",i==0&&j==0?"":" ",cinfo->quant_tbl_ptrs[i]->quantval[j]];

	return [self producersForTableString:tables];
}

-(NSArray *)producersForTableString:(NSString *)tables
{
	return [dict objectForKey:tables];
}

-(NSArray *)propertyArrayForTables:(struct jpeg_decompress_struct *)cinfo
{
	NSMutableArray *props=[NSMutableArray array];

	NSString *label=NSLocalizedString(@"Possible file creators",@"Possible file creators section title");

	NSArray *array=[self producersForTables:cinfo];
	if(!array)
	{
		[props addObject:[XeePropertyItem itemWithLabel:label
		value:NSLocalizedString(@"None known",@"None known property value string for possible creators")]];
	}
	else
	{
		[props addObjectsFromArray:[XeePropertyItem itemsWithLabel:label valueArray:array]];
	}

	for(int i=0;i<NUM_QUANT_TBLS&&cinfo->quant_tbl_ptrs[i];i++)
	{
		for(int j=0;j<8;j++)
		{
			NSString *label=@"";
			if(j==0) label=[NSString stringWithFormat:
			NSLocalizedString(@"Quantization table %d",@"Quantization table property title"),i];

			uint16_t *tbl=&cinfo->quant_tbl_ptrs[i]->quantval[j*8];

			#define PAD(i) (tbl[i]<10?"  ":"")
			[props addObject:[XeePropertyItem itemWithLabel:label
			value:[NSString stringWithFormat:@"%s%d, %s%d, %s%d, %s%d, %s%d, %s%d, %s%d, %s%d",
			PAD(0),tbl[0],PAD(1),tbl[1],PAD(2),tbl[2],PAD(3),tbl[3],
			PAD(4),tbl[4],PAD(5),tbl[5],PAD(6),tbl[6],PAD(7),tbl[7]]]];
			#undef PAD
		}
	}

	return props;
}

@end
