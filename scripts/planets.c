#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define MIN(x,y) ((x) < (y) ? (x) : (y))
#define MAX(x,y) ((x) > (y) ? (x) : (y))

int N = 6;
int M = 2;

typedef struct vector Vector;
struct vector {
	int size;
	union {
	    int i;
	    Vector *v;
	} a[0];
};

struct planet
{
	int x;
	int y;
};

int *dist;

Vector *vec_stack = NULL;

Vector *
new_vec(void)
{
	Vector *tmp;

	if (vec_stack) {
		tmp = vec_stack;
		vec_stack = *(Vector **)vec_stack;
	} else {
		tmp = malloc(sizeof(Vector)+(M*N)*sizeof(int));
	}
	tmp->size = 0;
	return tmp;
}

void
free_vec(Vector *vec)
{
	*(Vector **)vec = vec_stack;
	vec_stack = vec;
}

Vector *
append_vec(Vector *dst, Vector *src)
{
    int i;

    for (i=0; i < src->size; ++i) {
	dst->a[dst->size++].i = src->a[i].i;
    }
    return dst;
}
Vector *
append_vec1(Vector *dst, int src)
{
   dst->a[dst->size++].i = src;

   return dst;
}

void
print_vec(Vector *v)
{
	int i;

	printf("(");
	for(i = 0; i < v->size; ++i) {
		printf("%d", v->a[i].i + 1);
		if (i < v->size-1) 
			printf(",");
	}
	printf(")");
}

void 
print_vec_array(Vector *v) 
{
	int i;

	printf("(");
	for(i = 0; i < v->size; ++i) {
		print_vec(v->a[i].v);
		if (i < v->size-1) 
			printf(",");
	}
	printf(")");
}

int count = 0;
int best_d = 5000000;

void check(Vector *match) 
{ 
	int max_d = 0; 
	int c1, c2; 
	int p1, p2;

#ifdef DEBUG
	printf("answer==");
	print_vec_array(match);
	printf("\n");
#endif
	++count;
    
	for (c1=0; c1 < N; ++c1) {
		Vector *v = match->a[c1].v;
		
		for (p1=0; p1 < M; ++p1) {
			for (p2=p1+1; p2 < M; ++p2) {
				int d = dist[v->a[p1].i + v->a[p2].i * M * N];
				
				if (d >= best_d) 
					return;
				
				if (d > max_d) 
					max_d = d;
			}
		}
	}
	if (max_d < best_d) {
		int *is_friend;
		int friends = 0;
		int min_f = 500000;
		int max_f = 0;
		int total_f = 0;
		int enemies = 0;
		int min_e = 500000;
		int max_e = 0;
		int total_e = 0;

		best_d = max_d;
		print_vec_array(match);
		printf(" = %d\n", best_d);
		
		for (c1=0; c1 < N; ++c1) {
			Vector *v = match->a[c1].v;

			/* find max distance between partners on a team */
			int m = 0;
			for (p1 = 0; p1 < M; ++p1) {
				for (p2 = p1 + 1; p2 < M; ++p2) {
					int d = dist[v->a[p1].i + v->a[p2].i * M * N];

					m = MAX(m, d);
				}
			}
			++friends;
			min_f = MIN(min_f, m);
			max_f = MAX(max_f, m);
			total_f += m;
		}
		
		for (c1 = 0; c1 < N; ++c1) {
			Vector *v1 = match->a[c1].v;

			/* Find min distance to player on another team */
			int min_d = 500000;
			for (c2 = 0; c2 < N; ++c2) {
				Vector *v2 = match->a[c2].v;
				
				if (c1 == c2)
					continue;

				for (p1 = 0; p1 < M; ++p1) {
					for (p2 = 0; p2 < M; ++p2) {
						int d = dist[v1->a[p1].i + v2->a[p2].i * M * N];

						min_d = MIN(min_d, d);
					}
				}
			}
			++enemies;
			min_e = MIN(min_e, min_d);
			max_e = MAX(max_e, min_d);
			total_e += min_d;
		}

		printf("friends = %d / %d / %d\n", min_f, total_f/friends, max_f);
		printf("enemies = %d / %d / %d\n", min_e, total_e/enemies, max_e);
	}
}

void
search(int indent, Vector *current, Vector *done, Vector *todo, Vector *others)
{
    int i,j;
#ifdef DEBUG
    for(i=0;i<indent;i++)putchar(' ');
    printf("c=");
    print_vec(current);
    printf(" d=");
    print_vec_array(done);
    printf(" t=");
    print_vec(todo);
    printf(" o=");
    print_vec(others);
    printf("\n");
#endif
    for (i=0; i < todo->size - (M - current->size - 1); ++i) {
	Vector *new_current = append_vec(new_vec(), current);
	Vector *new_done = new_vec();
	Vector *new_others = append_vec(new_vec(), others);
	Vector *new_todo = new_vec();

	append_vec1(new_current, todo->a[i].i);
	for (j=0; j < done->size; ++j) {
	    append_vec1(new_done, (int)append_vec(new_vec(), done->a[j].v));
	}
	for (j=0; j < i; ++j) {
	    append_vec1(new_others, todo->a[j].i);
	}
	for (j=i+1; j < todo->size; ++j) {
	    append_vec1(new_todo, todo->a[j].i);
	}

	if (new_current->size == M) {
	    append_vec1(new_done, (int)append_vec(new_vec(), new_current));
	    new_current->size = 0;
	    append_vec(new_todo, new_others);
	    new_others->size = 0;
	   
	    if (new_done->size == N) {
#ifdef DEBUG
		    for(j=0;j<indent;j++)putchar(' ');
#endif
		check(new_done);
		
		free_vec(new_current);
		for(j=0; j < new_done->size; ++j) 
			free_vec(new_done->a[j].v);
		free_vec(new_done);
		free_vec(new_todo);
		free_vec(new_others);

		return;
	    }
	}
	search(indent+1,new_current, new_done, new_todo, new_others);

	free_vec(new_current);
	for(j=0; j < new_done->size; ++j) 
		free_vec(new_done->a[j].v);
	free_vec(new_done);
	free_vec(new_todo);
	free_vec(new_others);
    }
}

int
main()
{
    int i,j;
    struct planet *planets;
    Vector *current = new_vec();
    Vector *done = new_vec();
    Vector *todo = new_vec();
    Vector *others = new_vec();

    planets = malloc(M*N*sizeof(struct planet));
    for (i=0; i < M*N; i++) {
	scanf("%d %d", &planets[i].x, &planets[i].y);
	printf("%d x=%d y=%d\n", i, planets[i].x, planets[i].y);
    }
    dist = malloc(M*N*M*N*sizeof(int));
    for (i=0; i < M*N; i++) {
	for (j=0; j < M*N; j++) {
	    int x = abs(planets[i].x - planets[j].x);
	    int y = abs(planets[i].y - planets[j].y);

	    dist[i+j*M*N] = (int)hypot((double)x, (double)y);
	}
    }
    printf("done\n");

    for (i=0; i < M*N; i++) {
	todo->a[i].i = i;
    }
    todo->size = M*N;

    search(0, current, done, todo, others);

    printf("%d\n", count);

    return 0;
}

