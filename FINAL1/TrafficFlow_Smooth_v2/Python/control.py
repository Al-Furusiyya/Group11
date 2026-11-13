"""Deterministic traffic scheduler; no hardware, threads or wall clock.

N/S/E/W mean travel destinations, not the edge where a vehicle appears.
Five vehicles per approach use twenty independent VGA slots. Predictive conflict checks allow compatible traffic together; once admitted,
straight/right vehicles clear; left turns stage at the center before committing. All durations are simulation seconds.
"""
from dataclasses import dataclass
from enum import Enum
from functools import lru_cache
import bisect
import math
from protocol import Car, DisplayState, CAR_COUNT

N, S, E, W = range(4)
LEFT, STRAIGHT, RIGHT = range(3)
PERIOD = 5.0
STEP = 1.0 / 60.0
SPEED, SLOW_SPEED = 24.0, 6.0  # SLOW_SPEED retained for external scripts
ACCEL, BRAKE = 18.0, 30.0
TURN_SPEED, HEADWAY, JERK = 14.0, 0.65, 90.0
COMFORT_BRAKE = 8.0
LEFT_GAP_BUFFER = 0.65
SELECT_TIME, YELLOW_TIME, CLEAR_TIME = 2.0, 1.2, 0.8
LEFT_MAX_WAIT = 5.0
PREDICT_DT = 0.10
QUEUE_SIZE, QUEUE_GAP = 5, 16.0
WIRE_INDEX = (0, 2, 1, 3)  # GUI N,S,E,W -> wire N,E,S,W
SPRITE_DIRECTION = (2, 0, 3, 1)


class Phase(Enum):
    IDLE = 'IDLE'
    DEFAULT = 'DEFAULT'
    SELECT = 'SELECT'
    USER = 'USER'
    LEFT_APPROACH = 'LEFT_APPROACH'
    LEFT_WAIT = 'LEFT_WAIT'
    LEFT_GREEN = 'LEFT_GREEN'
    YELLOW = 'YELLOW'
    CLEAR = 'CLEAR'
    WALK = 'WALK'
    EMERGENCY = 'EMERGENCY'


def rotate(point, direction):
    x, y = point
    for _ in range((0, 2, 1, 3)[direction]):
        x, y = y, -x
    return x, y


def project(point):
    east, north = point
    return round(396 + 2*(east-north)), round(256-east-north)


@dataclass(frozen=True)
class Route:
    points: tuple
    lengths: tuple
    notice: float
    entry: float
    clear: float
    hold: float
    turn_end: float

    @property
    def total(self):
        return self.lengths[-1]

    def pose(self, distance):
        i = min(len(self.points)-2, max(0, bisect.bisect_right(self.lengths, distance)-1))
        a, b = self.points[i:i+2]
        t = max(0.0, min(1.0, (distance-self.lengths[i])/(self.lengths[i+1]-self.lengths[i])))
        p = (a[0]+(b[0]-a[0])*t, a[1]+(b[1]-a[1])*t)
        dx, dy = b[0]-a[0], b[1]-a[1]
        heading = (E if dx > 0 else W) if abs(dx) > abs(dy) else (N if dy > 0 else S)
        return p, heading


@lru_cache(maxsize=12)
def make_route(direction, movement):
    """Arc-length sampled Bezier turns and a smooth approach lane change."""
    points = []
    for n in range(-100, -31):
        lane = 11.25
        if movement == LEFT:
            t = max(0.0, min(1.0, (n+75)/23))
            lane -= 7.5*t*t*(3-2*t)
        points.append((lane, float(n)))
    entry_index = len(points)-1
    hold_index = entry_index
    if movement == STRAIGHT:
        points.extend((11.25, float(n)) for n in range(-31, 101))
        curve_end = entry_index
        clear_index = entry_index+76  # center +44; rear is clear of junction
    else:
        start = points[-1]
        if movement == RIGHT:
            c1, c2, end = (11.25, -20), (20, -11.25), (32, -11.25)
            sign, lane = 1, -11.25
        else:
            # Move straight into the intersection, keep the wheels straight,
            # then yield near the center before the curved crossing begins.
            points.extend((3.75,float(n)) for n in range(-31,-3))
            hold_index = len(points)-1
            start = points[-1]
            c1, c2, end = (3.75, 6), (-12, 11.25), (-32, 11.25)
            sign, lane = -1, 11.25
        for k in range(1, 65):
            t = k/64
            points.append(tuple((1-t)**3*start[j]+3*(1-t)**2*t*c1[j]+
                                3*(1-t)*t*t*c2[j]+t**3*end[j] for j in (0, 1)))
        curve_end = len(points)-1
        points.extend((float(sign*n), lane) for n in range(33, 101))
        clear_index = curve_end+12
    lengths = [0.0]
    for a, b in zip(points, points[1:]):
        lengths.append(lengths[-1]+math.hypot(b[0]-a[0], b[1]-a[1]))
    return Route(tuple(rotate(p, direction) for p in points), tuple(lengths),
                 lengths[48], lengths[entry_index], lengths[clear_index],
                 lengths[hold_index], lengths[curve_end])


@dataclass
class Vehicle:
    uid: int
    direction: int
    movement: int
    paint: int
    distance: float = 0.0
    speed: float = 0.0
    acceleration: float = 0.0
    turn_committed: bool = False
    admitted: bool = False
    locked: bool = False
    blend_offset: tuple = (0.0, 0.0)
    blend_start: float = 0.0
    blend_length: float = 1.0

    @property
    def route(self):
        return make_route(self.direction, self.movement)

    @property
    def in_junction(self):
        return self.admitted and self.distance < self.route.clear-1e-8

    def choose(self, movement):
        if self.locked or self.admitted:
            return False
        old_point, _ = self.pose()
        old = self.route
        i = max(0, bisect.bisect_right(old.lengths, self.distance)-1)
        fraction = (self.distance-old.lengths[i])/(old.lengths[i+1]-old.lengths[i])
        self.movement = movement
        new = self.route
        self.distance = new.lengths[i]+fraction*(new.lengths[i+1]-new.lengths[i])
        new_point, _ = new.pose(self.distance)
        self.blend_offset = (old_point[0]-new_point[0], old_point[1]-new_point[1])
        self.blend_start = self.distance
        self.blend_length = min(12.0, new.entry-2-self.distance)
        return True

    def pose(self):
        point, heading = self.route.pose(self.distance)
        t = max(0.0, min(1.0, (self.distance-self.blend_start)/self.blend_length))
        weight = 1-t*t*(3-2*t)
        return (point[0]+self.blend_offset[0]*weight,
                point[1]+self.blend_offset[1]*weight), heading


def travel(speed, seconds):
    """Distance under the same bounded acceleration used after admission."""
    ramp = min(seconds, max(0.0, (SPEED-speed)/ACCEL))
    return speed*ramp + 0.5*ACCEL*ramp*ramp + SPEED*(seconds-ramp)


def speed_profile(speed, seconds, target):
    """Exact bounded-acceleration distance and final speed toward target."""
    rate = ACCEL if target >= speed else -BRAKE
    ramp = min(seconds,abs(target-speed)/abs(rate))
    end = speed+rate*ramp
    return speed*ramp+0.5*rate*ramp*ramp+target*(seconds-ramp),end


def stopping_speed(gap):
    # Account for the velocity controller's 0.35 s response, so braking
    # begins early instead of relying on a last-frame stop-line clamp.
    lag=BRAKE*0.35
    return max(0.,math.sqrt(lag*lag+2*BRAKE*max(0,gap-.03))-lag)


def arrival_time(speed, distance, target):
    if distance <= 0:return 0.0
    rate = ACCEL if target >= speed else -BRAKE
    ramp = abs(target-speed)/abs(rate)
    ramp_distance = speed*ramp+0.5*rate*ramp*ramp
    if distance <= ramp_distance+1e-9:
        return (-speed+math.sqrt(max(0,speed*speed+2*rate*distance)))/rate
    return ramp+(distance-ramp_distance)/target


def free_motion(car, seconds):
    """Same future motion used by committed vehicles and safety prediction."""
    d,v = car.distance,car.speed
    if car.movement != STRAIGHT and d < car.route.turn_end:
        until = arrival_time(v,car.route.turn_end-d,TURN_SPEED)
        part = min(seconds,until)
        delta,v = speed_profile(v,part,TURN_SPEED);d += delta
        seconds -= part
    if seconds > 0:
        delta,v = speed_profile(v,seconds,SPEED);d += delta
    return d,v


def future_distance(car, seconds, completing_left=False):
    if car.movement == LEFT and not car.turn_committed and not completing_left:
        delta,_ = speed_profile(car.speed,seconds,TURN_SPEED)
        return min(car.route.hold,car.distance+delta)
    return free_motion(car,seconds)[0]


def crosswalk_segment(direction):
    # Ground/feet coordinates of the *same* four paths drawn in vga_scene.v.
    return (((-24.,-15.),(-24.,13.)),((22.,13.),(22.,-15.)),
            ((-15.,-24.),(13.,-24.)),((13.,22.),(-15.,22.)))[direction]


def segment_distance_squared(point,a,b):
    dx,dy=b[0]-a[0],b[1]-a[1]
    t=max(0.,min(1.,((point[0]-a[0])*dx+(point[1]-a[1])*dy)/(dx*dx+dy*dy)))
    return (point[0]-a[0]-t*dx)**2+(point[1]-a[1]-t*dy)**2


@lru_cache(maxsize=48)
def crosses_walk(direction,movement,pedestrian):
    # Reserve the entire zebra, not just the person's instantaneous position.
    # Radius 8 includes the car's circumscribed body, person and clearance.
    route=make_route(direction,movement)
    a,b=crosswalk_segment(pedestrian)
    return any(segment_distance_squared(route.pose(d)[0],a,b)<64
               for d in range(int(route.entry),math.ceil(route.clear)+1))


@lru_cache(maxsize=12)
def route_samples(direction, movement):
    route = make_route(direction, movement)
    result = []
    for d in range(math.ceil(route.total)+2):
        point, _ = route.pose(d)
        a, _ = route.pose(max(0, d-0.25))
        b, _ = route.pose(min(route.total, d+0.25))
        dx, dy = b[0]-a[0], b[1]-a[1]
        length = math.hypot(dx, dy) or 1
        result.append((*point, dx/length, dy/length))
    return tuple(result)


def footprint(car, distance):
    # One-unit lookup with interpolation removes repeated path searches from
    # the prediction loop. Tangents rotate continuously through a turn.
    samples = route_samples(car.direction, car.movement)
    distance = max(0.0, min(len(samples)-1.001, distance))
    i = int(distance); f = distance-i
    a, b = samples[i], samples[i+1]
    return tuple(x+(y-x)*f for x,y in zip(a,b))


def overlaps(a, b, margin=0.0):
    """Separating-axis test for 9.6 x 4.4 road-unit vehicle rectangles.

    Prediction adds a swept-motion margin for the 0.1-second sampling step.
    Tests can use zero margin to check the actual vehicle bodies.
    """
    dx,dy = b[0]-a[0], b[1]-a[1]
    if dx*dx+dy*dy > (12+4*margin)**2:
        return False
    length,width = 4.8+margin, 2.2+margin
    for ux,uy in ((a[2],a[3]),(-a[3],a[2]),(b[2],b[3]),(-b[3],b[2])):
        ra = length*abs(ux*a[2]+uy*a[3])+width*abs(-ux*a[3]+uy*a[2])
        rb = length*abs(ux*b[2]+uy*b[3])+width*abs(-ux*b[3]+uy*b[2])
        if abs(dx*ux+dy*uy) >= ra+rb:
            return False
    return True


@dataclass
class Request:
    direction: int
    pedestrian: bool = False
    movement: int = STRAIGHT
    explicit_turn: bool = False


class Controller:
    def __init__(self):
        self.reset()

    def reset(self, show_reset=False):
        self.state = DisplayState(ui_command=3 if show_reset else 0)
        self.phase, self.remaining, self.running = Phase.IDLE, 0.0, False
        self.vehicles = [None]*CAR_COUNT
        self.batch_uids = set()
        self.serial, self.priority = 0, 0
        self.alternation = [0]*4
        self.request = self.pending = self.target_uid = None
        self.target_cleared = self.peer_spawned = False
        self.input_mode = None
        self.emergency, self.resume = 0, None
        self.accumulator = self.elapsed = 0.0
        self.events = []
        self.selection_axis = self.yellow_axis = None
        self.after_yellow = Phase.SELECT
        self.after_clear = None
        self.left_wait = 0.0
        self._render()

    def _event(self, name, *values):
        self.events.append((round(self.elapsed, 6), name, *values))
        del self.events[:-256]

    def _phase(self, phase, seconds=PERIOD):
        self.phase, self.remaining = phase, seconds
        self._event('phase', phase.value)

    def _show_request(self, request):
        s = self.state
        s.menu_kind = 2 if request.pedestrian else 1
        s.direction, s.direction_valid = request.direction, True
        s.movement, s.turn_valid = request.movement, request.explicit_turn

    def _begin(self, request):
        ns, ew, _ = self._lights()
        old_axis = 0 if ns == 2 else 1 if ew == 2 else None
        self.request, self.target_uid = request, None
        self.left_wait = 0.0
        self.selection_axis = old_axis if old_axis == request.direction//2 else None
        self.target_cleared = self.peer_spawned = False
        self._show_request(request)
        if old_axis is not None and self.selection_axis is None:
            self.yellow_axis, self.after_yellow = old_axis, Phase.SELECT
            self._phase(Phase.YELLOW, YELLOW_TIME)
        else:
            self._phase(Phase.SELECT, SELECT_TIME)
        if not request.pedestrian:
            car = next((v for v in self._queue(request.direction)
                        if not v.locked and not v.admitted), None)
            if car:
                car.choose(request.movement)
                self.target_uid = car.uid
        self._spawn()
        self.batch_uids = {v.uid for v in self.vehicles if v and
                           v.direction//2 == request.direction//2}

    def handle(self, command):
        if command == 3:
            self.reset(show_reset=True)
            return
        if command == 1:
            if self.phase == Phase.IDLE:
                self._phase(Phase.DEFAULT)
                self._spawn()
            self.running, self.state.ui_command = True, 1
        elif command == 2 and self.phase != Phase.IDLE:
            self.running, self.state.ui_command = False, 2
        elif not self.running:
            return
        elif 12 <= command <= 15:
            flag = 1 << (command-12)
            if flag == self.emergency:
                self._release_emergency()
            else:
                if not self.emergency and not (self.phase == Phase.CLEAR and self.resume):
                    self.resume = (self.phase, self.remaining)
                self.emergency = flag
                self.state.menu_kind = 3
                self._phase(Phase.EMERGENCY, 0)
        elif command == 16:
            self.input_mode, self.pending = None, None
            if self.emergency:
                self._release_emergency()
            elif self.phase == Phase.DEFAULT:
                self.state.menu_kind = 0
                self.state.direction_valid = self.state.turn_valid = False
        elif self.emergency:
            return
        elif command == 11:
            self.input_mode = 'pedestrian'
            self.state.menu_kind = 2
            self.state.direction_valid = self.state.turn_valid = False
        elif 4 <= command <= 7:
            request = Request(command-4, self.input_mode == 'pedestrian')
            self.input_mode = None if request.pedestrian else 'turn'
            if self.phase == Phase.DEFAULT:
                self._begin(request)
            else:
                # Bounded queue: last pending request wins; no mid-turn reroute.
                self.pending = request
                self._show_request(request)
        elif 8 <= command <= 10 and self.input_mode == 'turn':
            request = self.pending or self.request
            if request and not request.pedestrian:
                can_choose = request is self.pending or ((self.phase == Phase.SELECT or (self.phase == Phase.YELLOW and self.after_yellow == Phase.SELECT)) and self.remaining > 1e-8)
                target = self._target()
                if can_choose and (request is self.pending or target is None or not target.locked):
                    request.movement, request.explicit_turn = command-8, True
                    if request is self.request and target:
                        target.choose(request.movement)
                    self._show_request(request)
        self._render()

    def _release_emergency(self):
        self.emergency = 0
        self._phase(Phase.CLEAR, CLEAR_TIME)
        if self.request:
            self._show_request(self.request)
        else:
            self.state.menu_kind = 0

    def _target(self):
        return next((v for v in self.vehicles if v and v.uid == self.target_uid), None)

    def _occupied(self, exclude_staged=False):
        return any(v and v.in_junction and not (exclude_staged and
                   v.uid == self.target_uid and v.movement == LEFT and not v.turn_committed)
                   for v in self.vehicles)

    def _walk_busy(self):
        return any(v and v.in_junction and crosses_walk(v.direction,v.movement,self.request.direction)
                   for v in self.vehicles)

    def _walk_reserved(self):
        return self.request and self.request.pedestrian and self.phase in (Phase.SELECT,Phase.WALK)

    def _queue(self, direction):
        return sorted((self.vehicles[direction+4*i] for i in range(QUEUE_SIZE)
                if self.vehicles[direction+4*i] is not None),key=lambda v:v.uid)

    def _batch_cleared(self):
        return not any(v and v.uid in self.batch_uids and
                       (not v.admitted or v.in_junction) for v in self.vehicles)

    def _new_car(self, direction, movement, target=False):
        self.serial += 1
        car = Vehicle(self.serial, direction, movement, (self.serial-1) % 3)
        queue = self._queue(direction)
        # Cars waiting outside the visible road enter at normal spacing. They
        # retain their own route/identity; they are not copies of the leader.
        if queue:
            car.distance = min(0.0, min(v.distance for v in queue)-QUEUE_GAP)
        # Stable slot identity: removing a car must not move all its followers
        # into other VGA sprite registers and trigger visual discontinuities.
        slot=next(direction+4*i for i in range(QUEUE_SIZE) if self.vehicles[direction+4*i] is None)
        self.vehicles[slot] = car
        if target:
            self.target_uid = car.uid
        self._event('spawn', car.uid, direction, movement)

    def _spawn(self):
        if self.phase == Phase.DEFAULT:
            for direction in (E, W):
                while len(self._queue(direction)) < QUEUE_SIZE:
                    turn = STRAIGHT if self.alternation[direction] % 2 == 0 else RIGHT
                    self.alternation[direction] += 1
                    self._new_car(direction, turn)
        elif self.request and self.request.pedestrian and self.phase in (Phase.SELECT,Phase.WALK):
            for direction in (2*(self.request.direction//2),2*(self.request.direction//2)+1):
                while len(self._queue(direction)) < QUEUE_SIZE:
                    turn=STRAIGHT if self.alternation[direction]%2 == 0 else RIGHT
                    self.alternation[direction]+=1
                    self._new_car(direction,turn)
        elif self.request and not self.request.pedestrian and self.phase in (Phase.SELECT, Phase.YELLOW, Phase.USER, Phase.LEFT_APPROACH, Phase.LEFT_WAIT):
            d = self.request.direction
            peer = (S, N, W, E)[d]
            if self.target_uid is None:
                car = next((v for v in self._queue(d) if not v.locked and not v.admitted), None)
                if car:
                    car.choose(self.request.movement)
                    self.target_uid = car.uid
                elif len(self._queue(d)) < QUEUE_SIZE:
                    self._new_car(d, self.request.movement, target=True)
            if not self.peer_spawned:
                for direction in (d, peer):
                    # During user service the unselected cars default straight.
                    for car in self._queue(direction):
                        if car.uid != self.target_uid and not car.locked and not car.admitted:
                            car.choose(STRAIGHT)
                    while len(self._queue(direction)) < QUEUE_SIZE:
                        self._new_car(direction, STRAIGHT)
                self.peer_spawned = True
            self.batch_uids.update(v.uid for v in self.vehicles if v and v.direction in (d, peer))

    def _lights(self):
        ns = ew = left = 0
        axis = None
        if self.phase == Phase.DEFAULT:
            axis = 1
        elif self.phase in (Phase.USER, Phase.LEFT_APPROACH, Phase.LEFT_WAIT) and self.request:
            axis = self.request.direction//2
        elif self.phase == Phase.SELECT:
            axis = self.selection_axis
        elif self.phase == Phase.WALK and self.request:
            axis = self.request.direction//2
        if axis is not None:
            if axis == 0: ns = 2
            else: ew = 2
        if self.phase == Phase.YELLOW:
            if self.yellow_axis == 0: ns = 1
            elif self.yellow_axis == 1: ew = 1
        elif self.phase == Phase.LEFT_GREEN and self.request:
            left = 1 << (3-WIRE_INDEX[self.request.direction])
        return ns, ew, left

    def _can_enter(self, car):
        if self._walk_reserved() and crosses_walk(car.direction,car.movement,self.request.direction):
            return False
        ns, ew, left = self._lights()
        main_green = (ns if car.direction in (N, S) else ew) == 2
        if car.movement == LEFT:
            return car.uid == self.target_uid and (main_green or bool(left & (1 << (3-WIRE_INDEX[car.direction]))))
        return main_green

    def _trajectory_safe(self, car, turning=False):
        protected=bool(self._lights()[2])
        others=[v for v in self.vehicles if v and v is not car and
                (v.admitted or (turning and not protected and
                 v.direction==(S,N,W,E)[car.direction] and v.movement!=LEFT and self._can_enter(v)))]
        # Give the rear of the last opposing straight car visible clearance
        # beyond the central conflict point, rather than cutting behind it.
        if turning:
            for other in others:
                if (other.direction==(S,N,W,E)[car.direction] and other.movement==STRAIGHT
                    and other.admitted and other.distance<other.route.entry+44):
                    return False
        if not others:return True
        horizon=min(14.,(car.route.total-car.distance)/TURN_SPEED+SPEED/ACCEL)
        for k in range(math.ceil(horizon/PREDICT_DT)+1):
            t=k*PREDICT_DT
            distance=future_distance(car,t,completing_left=turning)
            if distance>car.route.total+6:break
            a=footprint(car,distance)
            for other in others:
                opposing=turning and other.direction==(S,N,W,E)[car.direction]
                offsets=(-LEFT_GAP_BUFFER,0.,LEFT_GAP_BUFFER) if opposing else (0.,)
                for offset in offsets:
                    od=future_distance(other,max(0,t+offset))
                    if od<0 or od>other.route.total+6:continue
                    if distance<car.route.entry-1 and od<other.route.entry-1:continue
                    if overlaps(a,footprint(other,od),margin=1.4):return False
        return True

    def _safe_entry(self, car):
        # Left admission reserves a straight approach and its center waiting
        # pocket. Crossing opposing traffic is a separate, later decision.
        return self._trajectory_safe(car)

    def _safe_turn(self, car):
        if self._walk_reserved() and crosses_walk(car.direction,LEFT,self.request.direction):
            return False
        return self._trajectory_safe(car,turning=True)

    def _turn_permission(self, car):
        # Already entered cars can clear an emergency hold. Protected-left
        # clearance excludes the staged target but waits for everybody else.
        if self.phase==Phase.CLEAR and self.after_clear==Phase.LEFT_GREEN and not self.resume:
            return False
        ns,ew,left=self._lights()
        return ((ns if car.direction in (N,S) else ew)==2 or
                bool(left & (1<<(3-WIRE_INDEX[car.direction]))) or
                self.phase in (Phase.YELLOW,Phase.EMERGENCY) or
                (self.phase==Phase.CLEAR and bool(self.resume)))

    def _approach_motion(self, car, dt, desired, limit=float('inf'), stopping=False):
        # Continuous headway feedback replaces the previous threshold that
        # repeatedly accelerated/braked cars around the same queue gap.
        gap=limit-car.distance
        if stopping and car.speed>0 and gap<=car.speed*car.speed/(2*COMFORT_BRAKE)+0.02:
            # Plan the final braking segment to end at the waiting point.
            # Exact integration prevents the old 5-6 unit/s contact clamp.
            rate=min(BRAKE,car.speed*car.speed/(2*max(gap,1e-8)))
            duration=min(dt,car.speed/max(rate,1e-8))
            delta=car.speed*duration-0.5*rate*duration*duration
            car.speed=max(0,car.speed-rate*duration);car.acceleration=-rate
            car.distance=min(limit,car.distance+delta)
            if duration<dt or (limit-car.distance<0.002 and car.speed<0.2):
                car.distance=limit;car.speed=0.;car.acceleration=0.
            return
        requested=max(-BRAKE,min(ACCEL,(desired-car.speed)/0.35))
        car.acceleration=max(car.acceleration-JERK*dt,min(car.acceleration+JERK*dt,requested))
        old_speed=car.speed
        car.speed=max(0,min(SPEED,old_speed+car.acceleration*dt))
        if old_speed<desired and car.speed>desired:car.speed=desired
        proposed=car.distance+(old_speed+car.speed)*0.5*dt
        if proposed>=limit:
            proposed=limit
            car.speed=0.;car.acceleration=0.
        car.distance=max(car.distance,proposed)

    def _same_lane(self, a, b):
        # Once the early lane change has finished, straight followers may
        # pass a yielding left-turn car in the separate outer lane.
        split = a.distance >= a.route.notice and b.distance >= b.route.notice
        return not (split and ((a.movement == LEFT) != (b.movement == LEFT)))

    def _move(self, dt):
        for car in self.vehicles:
            if car and car.admitted:
                if car.movement==LEFT and not car.turn_committed:
                    gap=car.route.hold-car.distance
                    if gap<=6 and self._turn_permission(car) and self._safe_turn(car):
                        car.turn_committed=True
                        self._event('turn',car.uid,car.direction,self.phase.value)
                    if not car.turn_committed:
                        desired=min(TURN_SPEED,stopping_speed(gap))
                        self._approach_motion(car,dt,desired,car.route.hold,stopping=True)
                if car.movement!=LEFT or car.turn_committed:
                    car.distance,car.speed=free_motion(car,dt)
                if car.uid==self.target_uid and not car.in_junction:self.target_cleared=True
        for offset in range(4):
            d=(self.priority+offset)%4
            queue=sorted(self._queue(d),key=lambda v:v.distance-v.route.entry,reverse=True)
            for index,car in enumerate(queue):
                if car.admitted:continue
                gap=car.route.entry-car.distance
                allowed=self._can_enter(car)
                lookahead=car.speed*car.speed/(2*BRAKE)+8
                if allowed and gap<=max(18,lookahead):allowed=self._safe_entry(car)
                cap=SPEED if car.movement==STRAIGHT else min(SPEED,math.sqrt((TURN_SPEED+4.2)**2+24*max(0,gap))-4.2)
                desired=cap if allowed else min(cap,stopping_speed(gap))
                limit=float('inf') if allowed else car.route.entry
                for leader in queue[:index]:
                    if self._same_lane(car,leader):
                        available=car.route.entry+leader.distance-leader.route.entry-car.distance-QUEUE_GAP
                        limit=min(limit,car.distance+max(0,available))
                        desired=min(desired,max(0,leader.speed+0.9*(available-HEADWAY*car.speed)))
                previous=car.distance
                self._approach_motion(car,dt,desired,limit,stopping=not allowed and limit==car.route.entry)
                if car.distance>=car.route.entry-1e-9:
                    if allowed and self._can_enter(car) and self._safe_entry(car):
                        car.admitted=True
                        car.turn_committed=car.movement!=LEFT
                        self._event('enter',car.uid,d,car.movement,self.phase.value)
                    else:
                        car.distance=max(previous,car.route.entry);car.speed=0.;car.acceleration=0.
                if car.distance>=car.route.notice:car.locked=True
        self.priority=(self.priority+1)%4
        for index,car in enumerate(self.vehicles):
            if car and car.distance>=car.route.total:
                self._event('exit',car.uid,car.direction)
                self.vehicles[index]=None

    def _end_green(self, destination):
        ns,ew,_ = self._lights()
        self.yellow_axis = 0 if ns == 2 else 1 if ew == 2 else None
        self.after_yellow = destination
        self._phase(Phase.YELLOW,YELLOW_TIME)

    def _finish_clearance(self):
        if self.resume:
            phase,remaining = self.resume
            self.resume = None
            self._phase(phase,remaining)
        elif self.after_clear:
            phase,self.after_clear = self.after_clear,None
            target=self._target()
            if phase==Phase.LEFT_GREEN and (target is None or target.turn_committed):phase=Phase.USER
            self._phase(phase,PERIOD)
        elif self.pending:
            request,self.pending = self.pending,None
            self._begin(request)
        else:
            self.request = self.target_uid = None
            self.state.menu_kind = 0
            self.state.direction_valid = self.state.turn_valid = False
            self.input_mode = None
            self._phase(Phase.DEFAULT)

    def _step(self, dt):
        self.elapsed += dt
        self._spawn()
        self._move(dt)
        self.remaining = max(0.0,self.remaining-dt)
        target = self._target()
        if self.phase == Phase.DEFAULT and self.remaining <= 1e-8:
            self.remaining = PERIOD
        elif self.phase == Phase.YELLOW and self.remaining <= 1e-8:
            if self.after_yellow == Phase.SELECT:
                self._phase(Phase.SELECT,SELECT_TIME)
            else:
                self.after_clear = self.after_yellow if self.after_yellow == Phase.LEFT_GREEN else None
                self._phase(Phase.CLEAR,CLEAR_TIME)
        elif self.phase == Phase.SELECT and self.remaining <= 1e-8:
            # Same-axis selection may keep its existing green. Other changes
            # wait for the actual rear of the last vehicle, not a fixed guess.
            ready=not self._walk_busy() if self.request.pedestrian else (self.selection_axis is not None or not self._occupied())
            if ready:self._phase(Phase.WALK if self.request.pedestrian else Phase.USER)
        elif self.phase in (Phase.USER,Phase.LEFT_APPROACH,Phase.LEFT_WAIT):
            if target and target.movement == LEFT and not target.turn_committed:
                if target.admitted and target.distance >= target.route.hold-0.25 and target.speed < 1:
                    self.left_wait += dt
                    if self.phase != Phase.LEFT_WAIT:
                        self._phase(Phase.LEFT_WAIT,LEFT_MAX_WAIT-self.left_wait)
                    self.remaining = max(0,LEFT_MAX_WAIT-self.left_wait)
                    if self.left_wait >= LEFT_MAX_WAIT:
                        self._end_green(Phase.LEFT_GREEN)
            elif self.phase == Phase.LEFT_WAIT:
                self._phase(Phase.USER)
            elif self.target_cleared and self._batch_cleared():
                self._end_green(Phase.CLEAR)
        elif self.phase == Phase.LEFT_GREEN:
            if target is None or (target.admitted and not target.in_junction):
                self._phase(Phase.USER)
        elif self.phase == Phase.WALK and self.remaining <= 1e-8:
            self._end_green(Phase.CLEAR)
        elif self.phase == Phase.CLEAR and self.remaining <= 1e-8 and not self._occupied(exclude_staged=self.after_clear==Phase.LEFT_GREEN and not self.resume):
            self._finish_clearance()

    def _render(self):
        s = self.state
        s.light_ns, s.light_ew, s.left_green = self._lights()
        s.emergency, s.ped_walk, s.ped_progress = self.emergency, 0, 0
        s.seconds = [0]*4
        s.phase = {Phase.IDLE: 0, Phase.DEFAULT: 1, Phase.USER: 1, Phase.SELECT: 2,
                   Phase.LEFT_APPROACH: 3, Phase.LEFT_WAIT: 3, Phase.LEFT_GREEN: 4,
                   Phase.CLEAR: 5, Phase.YELLOW: 5, Phase.WALK: 6, Phase.EMERGENCY: 7}[self.phase]
        s.phase_seconds = min(5, max(0, math.ceil(self.remaining-1e-8)))
        if self.phase == Phase.USER:
            # FLOW ends on actual clearance. Its capped countdown is an ETA,
            # rather than a timer that can expire while a queue is still moving.
            eta = max((max(0,v.route.clear-v.distance)/SPEED +
                       max(0,SPEED-v.speed)/(2*ACCEL)
                       for v in self.vehicles if v and v.uid in self.batch_uids and
                       (not v.admitted or v.in_junction)),default=0)
            s.phase_seconds = min(5,math.ceil(eta-1e-8))
        if self.phase == Phase.WALK:
            i = WIRE_INDEX[self.request.direction]
            s.ped_walk = 1 << (3-i)
            s.seconds[i] = s.phase_seconds
            s.ped_progress = min(63, round(63*(1-self.remaining/PERIOD)))
        elif self.phase in (Phase.SELECT, Phase.YELLOW, Phase.CLEAR, Phase.LEFT_WAIT, Phase.LEFT_GREEN, Phase.DEFAULT, Phase.USER):
            s.seconds = [s.phase_seconds]*4
        s.cars = [Car(0, 0, visible=False) for _ in range(CAR_COUNT)]
        for d, car in enumerate(self.vehicles):
            if car and car.distance >= 0:
                point, heading = car.pose()
                x, y = project(point)
                s.cars[d] = Car(x, y, SPRITE_DIRECTION[heading], car.paint)

    def update(self, dt, animate=True):
        """Advance simulated seconds; animate retained for old CLI compatibility."""
        if not math.isfinite(dt) or dt < 0:
            raise ValueError('elapsed time must be finite and nonnegative')
        if self.running:
            self.accumulator += dt
            steps = int((self.accumulator+1e-10)/STEP)
            self.accumulator -= steps*STEP
            for _ in range(steps):
                self._step(STEP)
        self._render()
        return self.state
