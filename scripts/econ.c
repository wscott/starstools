#include <stdio.h>
#include <stdlib.h>
#include <math.h>

int pop_eff;
int fact_eff;
int fact_cost;
int fact_oper;
int fact_g;
int mine_eff;
int mine_cost;
int mine_oper;

struct factors {
    char *name;
    int *global;
    int min, max;
    int costs[25];
} factors[] = {
  {"pop_eff", &pop_eff, 7, 25,
   {-799,-419,-199,0,40,80,120,160,200,240,280,
    320,360,400,440,480,520,560,600}},
  {"fact_eff", &fact_eff, 5, 15,
   {167,134,100,67,34,0,-41,-83,-144,-206,-267}},
  {"fact_cost", &fact_cost, 5, /* 25 */ 10,
   {-499,-319,-179,-79,-19,0,19,37,55,74,92,110,129,
    147,165,184,202,220,235,241,247}},
  {"fact_oper", &fact_oper, 5, 25,
   {67,54,40,27,14,0,-13,-26,-38,-51,-64,-77,-99,-122,-145,-168,
    -191,-228,-256,-284,-312}},
  {"fact_g", &fact_g, 3, 4, {-57, 0}},
  {"mine_eff", &mine_eff, 5, 25,
   {167,134,100,67,34,0,-55,-112,-168,-224,-281,-337,
    -393,-450,-506,-562,-619,-675,-731,-788,-844}},
  {"mine_cost", &mine_cost, 2, /* 15 */ 5,
   {-189,-42,-21,0,22,44,65,87,109,130,152,174,195,217}},
  {"mine_oper", &mine_oper, 5, 25,
   {67,54,40,27,14,0,-11,-22,-34,-46,-57,-69,
    -81,-92,-104,-116,-127,-139,-151,-162,-174}}
};
#define NUM_FACTORS (sizeof(factors)/sizeof(struct factors))

int calc_cost(void);
int calc_maxres(void);
int calc_maxres_double(void);
int calc_invest(void);
int calc_mine(void);

struct limits {
    char *name;
    int min;
    int max;
    int (*fcn)(void);
    int val;
    int best[NUM_FACTORS];
} limits[] = {
  {"max resource", 3344, -10000, calc_maxres},
  {"max_mine", 1870, -10000, calc_mine},
  {"cost", -500, -10000, calc_cost},
  {"max_res_double", 3344, -10000, calc_maxres_double},
  {"invest", 136, -10000, calc_invest}
};
#define NUM_LIMITS (sizeof(limits)/sizeof(struct limits))

int
calc_cost(void)
{
    int i;
    int cost = 0;

    for (i=0; i < NUM_FACTORS; i++) {
	cost += factors[i].costs[*(factors[i].global) - factors[i].min];
    }
    return cost;
}

int
calc_mine(void)
{
	return (11 * mine_oper * mine_eff);
}

int 
calc_maxres_double(void)
{
    return(16500 / pop_eff + 11 * fact_oper * fact_eff);
}

int 
calc_maxres(void)
{
    return(11000 / pop_eff + 11 * fact_oper * fact_eff);
}

int
calc_invest(void)
{
	double ratio;

	ratio = 200.0 * fact_eff / 
		(fact_cost + sqrt(fact_cost * fact_cost + 
				  4 * mine_cost * fact_g * 2 * (double)fact_eff/10.0));

	return (int)ratio;
}

print_values()
{
    int i;
    for (i=0; i < NUM_FACTORS; i++) {
	printf("%s=%d ", factors[i].name, *factors[i].global);
    }
    printf("\n");
 }

main()
{
    int i;
    int fact_num;
    int lim;

    int *fact;
    int total = 1;

    printf("Seach factors:\n");
    for (i=0; i < NUM_FACTORS; i++) {
	printf("\t%s %d to %d\n", factors[i].name, factors[i].min, factors[i].max);
	total *= factors[i].max - factors[i].min + 1;

	fact = factors[i].global;
	*fact = factors[i].min;
    }
    printf("Total of %d combinations\n\n", total);

    while (1) {
	int good = 1;

	/* compute limits */
	for (lim=0; lim < NUM_LIMITS; lim++) {

	    limits[lim].val = (limits[lim].fcn)();
	    if (limits[lim].val < limits[lim].min) {
		good = 0;
		break;
	    }
	}
	if (good) {
	    for (lim=0; lim < NUM_LIMITS; lim++) {
		if (limits[lim].val > limits[lim].max) {
		    limits[lim].max = limits[lim].val;

		    for (i=0; i < NUM_FACTORS; i++) {
			limits[lim].best[i] = *factors[i].global;
		    }
		}
	    }
	}


	fact_num = 0;
	while (1) {
	    if (*factors[fact_num].global < factors[fact_num].max) {
		++*factors[fact_num].global;
		break;
	    } else {
		*factors[fact_num].global = factors[fact_num].min;
		++fact_num;

		if (fact_num == NUM_FACTORS) 
		    goto done;
	    }
	}
    }
done:
    for (lim=0; lim < NUM_LIMITS; lim++) {
	    int lim2;

	    printf("best %s:\n\t", limits[lim].name, limits[lim].max);
	    for (i=0; i < NUM_FACTORS; i++) {
		    printf("%s=%d ", factors[i].name, limits[lim].best[i]);
		    *factors[i].global = limits[lim].best[i];
	    }
	    printf("\n\t");
	    for (lim2=0; lim2 < NUM_LIMITS; lim2++) {
		    printf("%s=%d ", limits[lim2].name, (limits[lim2].fcn)());
	    }
	    printf("\n");
    }
}
