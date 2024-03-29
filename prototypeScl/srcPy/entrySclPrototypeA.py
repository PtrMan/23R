### basic idea: compute "novelity" of text data by ratio to compressed text in known "database"

import time
import random

#########################
# python utils

# ensures that v has type "type_". it is a fatal error when this is not the case
def ensureType(v, type_):
    if not isinstance(v, type_):
        raise Exception('FATAL: expected type didnt match')







#########################
#########################
#########################


#
class ResourceBoundedTableEntry(object):
    def __init__(self):
        self.items = []


# table maintainer with bounds on memory
class ResourceBoundedTable(object):
    def __init__(self, maxCapacity):
        self.dat = {}  # table content

        self.maxCapacity = maxCapacity  # max capacity of items in the table

    # adds the item with value under the key
    def put(self, key, value):
        if key in self.dat:
            # TODO LOW  :  we simply add it here independent on if the content already exists or not!
            #              we MUST call a method here which checks if the same data already exists

            self.dat[key].items.append(value)
        else:
            createdTableEntry = ResourceBoundedTableEntry()
            createdTableEntry.items.append(value)
            self.dat[key] = createdTableEntry

    def maintainResourceBounds(self):
        # algorithm
        # 1) extract all items from all entries in the table
        # 2) sort them by decreasing order by calling self._retPriorityOfItem() for each item
        # 3) limit length of list to self.maxCapacity
        # 4) clear self.dat and put items from list back into self.dat

        allItems = []
        for key, tableEntry in self.dat.items():
            allItems.extend(tableEntry.items)

        # Sort items by priority using _retPriorityOfItem (assuming priority exists)
        sortedItems = sorted(allItems, key=self._retPriorityOfItem, reverse=True)

        # Truncate list to max capacity
        self.dat = {}
        for item in sortedItems[:self.maxCapacity]:
            self.put(item.key, item)

    # return all as a list
    def retAllItems(self):
        allItems = []
        for key, tableEntry in self.dat.items():
            allItems.extend(tableEntry.items)
        return allItems

    def _retPriorityOfItem(self, item):
        return 0.0  # TODO LOW

#########################
#########################
#########################


# class was created on 7.3.2023
class SclScheduler(object):
    def __init__(self):
        # set of pending inactive tasks
        # 'activeFrom' is the system clock time from when the task will get activated into "activeTasks"
        self.pendingInactiveTasks = []

        # set of active tasks
        self.activeTasks = []


        self.cachedSystemClockTime = 0.0 # system clock time

        self.systemStartAbsoluteTime = 0.0

    # add a job
    def putJob(self, job):
        # TODO LOW  :  maintain AIKR because this here could easily overflow the system

        self.pendingInactiveTasks.append(job)


# tick for "SchedulerA" object
#
# is implementing the basic scheduling
def schedulerTick(scheduler, globalCtx):
    scheduler.cachedSystemClockTime = time.time() - scheduler.systemStartAbsoluteTime


    # * iterate over jobs to move them to active tasks 
    idx0 = len(scheduler.pendingInactiveTasks)-1
    while idx0 >= 0:
        #print('[trace] scheduler: process pending job') # verbose

        itJob = scheduler.pendingInactiveTasks[idx0]

        if scheduler.cachedSystemClockTime > itJob['activeFrom']: # do we need to activate the job?
            scheduler.activeTasks.append(itJob)
            del scheduler.pendingInactiveTasks[idx0] # remove at index

        idx0-=1
    

    # * select task with the highest priority
    selTask = None
    # TODO LOW  :  select task by highest utility
    if len(scheduler.activeTasks) > 0:
        selTask = scheduler.activeTasks[0]
        del scheduler.activeTasks[0] # remove from set of tasks
    

    # * actual processing of task
    if selTask is not None: # has a task been select for execution?
        if True: # codeblock
            if selTask['kind'] == 'goal':
                typeName = selTask['val'].type_.typeName
            elif selTask['kind'] == 'event':
                typeName = selTask['val'].payload.type_.typeName
            print(f'[trace] processing task kind={selTask["kind"]} SclType={typeName} ...')
        
        if selTask['kind'] == 'goal': # the job is to process a goal with backward-inference

            goaltoProcess = selTask['val'] # the goal to get processed is the value which is hold by the job




            pass 
            #print(goaltoProcess) # DBG DBG DBG

            # * call into "RuleManager" to apply all rules backward for a instance of goalA
            inputTypedInsts = globalCtx.ruleManager.applyBackwardAll(goaltoProcess)

            print(f'[trace] #inputTypedInsts={len(inputTypedInsts)}') # debug number of input "TypedInst" which we can use for forward execution

            # * add "derivedInputTypedInsts" as sub-goals to the system
            #   (because we need to process the derived sub-goals at a later point)
            for iInputTypedInst in inputTypedInsts:

                derivedGoalTypedInst = iInputTypedInst['derivedGoal']
                
                createdPendingTask = {}
                createdPendingTask['activeFrom'] = 0.0 # set absolute time when the job will be added as active job
                createdPendingTask['kind'] = 'goal' # job is to process a goal with backward-inference
                createdPendingTask['val'] = derivedGoalTypedInst # actual job is to process the goal with backward inference
                globalCtx.scheduler.pendingInactiveTasks.append(createdPendingTask)

            # * add "SclEventDetector" detectors for every derived goal, so the system can detect the coresponding SclEvent
            for iValue in inputTypedInsts:
                iRule = iValue['rule']
                createdEventDetector = SclEventDetector(iRule)

                key = None # TODO LOW  :  what should be the key here? probably the typename is the best option here
                globalCtx.eventDetectors.put(None, createdEventDetector)


            '''
            # we maintain "TypedInst" which we have to process as 'spikes'. This simplifies resource management and queueing
            queuedTypedInstSpikes = []


            # put all derived "TypedInst" from "inputTypedInsts" into spikes to be processed next
            for iInputTypedInsts in inputTypedInsts:
                queuedTypedInstSpikes.append(iInputTypedInsts)

            '''

            '''
            # * notify eventManager about all 'spikes' in "queuedTypedInstSpikes"
            for iInputTypedInsts in queuedTypedInstSpikes:

                iInputTypedInstAsEvent = SclEvent(iInputTypedInsts) # wrap TypedInst into event to be processed with eventmanager
                globalCtx.eventManager.processEvent(iInputTypedInstAsEvent) # process the event
            '''

            # commented because not necessary
            #queuedTypedInstSpikes = [] # flush them because we did process the spikes


        elif selTask['kind'] == 'event': # the job is to process a SclEvent with forward-inference

            eventToProcess = selTask['val'] # the event to get processed is the value which is hold by the job

            # notify event manager that the event is handled
            # (commented because not used yet)
            #globalCtx.eventManager.processEvent(eventToProcess)

            conclusionTypedInsts = []

            # process the event
            for iEventDetector in globalCtx.eventDetectors.retAllItems():
                if iEventDetector.checkPatternMatch(eventToProcess): # check if event matches to pattern of the actual detector
                    
                    # ( we collect derived events from the forward process )
                    inputTypedInst = eventToProcess.payload

                    conclusionTypedInstsThis = iEventDetector.rule.applyForward(inputTypedInst)
                    conclusionTypedInsts += [conclusionTypedInstsThis]

            # now we need to add derived events as jobs to get processed
            for iConclusionTypedInst in conclusionTypedInsts:
                
                createdPendingTask = {}
                createdPendingTask['activeFrom'] = 0.0 # set absolute time when the job will be added as active job
                createdPendingTask['kind'] = 'event' # job is to process a event with forward-inference
                createdPendingTask['val'] = SclEvent(iConclusionTypedInst) # actual job is to process the event with forward inference
                globalCtx.scheduler.pendingInactiveTasks.append(createdPendingTask)

            pass
            
        else:
            raise InternalTerminatingException('invalid job-kind encountered! this is fatal because it is a internal inconsistency of the program')

        print(f'[trace] ...done')




# manual test of the scheduler
if False:
    z0 = SclScheduler()

    createdPendingTask = {}
    createdPendingTask['activeFrom'] = 2.0 # set absolute time when the job will be added as active job
    z0.pendingInactiveTasks.append(createdPendingTask)

    z0.systemStartAbsoluteTime = time.time()

    while True:
        # HACKY  :  kill the whole system after it did run for a given time amount
        if z0.cachedSystemClockTime > 3.0:
            break
        
        schedulerTick(z0)

    # terminate program
    exit(0)





















# "type" as explained in book "The Road to General Intelligence"
class Type(object):
    # /param typeId (string) globally unique name of the type
    def __init__(self, typeName):
        self.typeName = typeName

# typed instantiation : holds data of a type "Type"
class TypedInst(object):
    # /param type_ the type of type "Type"
    def __init__(self, type_):
        self.type_ = type_

        self.dat = None # actual data
        
        pass

# "rule" as explained in book "The Road to General Intelligence"
# a rule is a function which transforms a input datum of a fixed type to a output datum of a fixed type
#
# explanation: a rule is basically a contract which guarantees that a typed input datum is transformed to an output
class SclRule(object):
    # /param fn function which can be applied to input of "TypedInst" to return output of "TypedInst"
    def __init__(self, inputType, outputType, fn):
        self.inputType = inputType
        self.outputType = outputType
        self.fn = fn

    def applyForward(self, forwardInput):
        ensureType(forwardInput, TypedInst)
        
        return self.fn.applyForward(forwardInput)
    
    def applyBackward(self, backwardOutput):
        ensureType(backwardOutput, TypedInst)
        
        return self.fn.applyBackward(backwardOutput)













########################################
## Event management: SclEvent + EventWatchdog + ScnEventManager

## AERA-like

class SclEvent(object):
    def __init__(self, payload):
        ensureType(payload, TypedInst) # payload must be of this type!!!
        self.payload = payload


##
# a "SclEventDetector" pattern matches an incomming "SclEvent" to the pattern for which the system is looking for and sends the "SclEvent" for further processing on a successful match.
#
#
class SclEventDetector(object):
    # /param rule rule which has to be applied when the pattern matching succeeded
    def __init__(self, rule):
        self.rule = rule

    # called to check if the pattern matches
    # /param e is a "SclEvent"
    def checkPatternMatch(self, e):
        if e.payload.type_.typeName != self.rule.inputType.typeName:
            return False # types are not the same, can't match
        
        # TODO LOW  :  here we are doing more pattern matching!

        return True
    



'''
# IDEA here: SclEventWatchdog is a 'detector' which gets triggered when a SclEvent of type SclType did occur.
#            the purpose is so that we can invoke a function to do forward inference.
class SclEventWatchdog(object):
    # /param fn function to get invoked when the watchdog was triggered with a matching SclEvent
    def __init__(self, detectorType, fn):
        ensureType(detectorType, Type)
        self.detectorType = detectorType
        self.fn = fn

    # get called when a SclEvent with type "self.detectorType" did occur
    #
    # /return list of derived "SclEvent" 's
    def trigger(self, arg):
        ensureType(arg, SclEvent)
        return self.fn(arg) # invoke actual function which was registered to get invoked when ever a SclEvent with the right type did occur



class SclEventManager(object):
    def __init__(self):
        # set of all "SclEventWatchdog" which are on the lookout for occurring events of a specific "SclType"
        self.eventWatchdogs = []

    # called when ever an event occurred and has to get processed
    #
    # /return derived events which need to get eventually processed at some point
    def processEvent(self, event):
        ensureType(event, SclEvent)

        print(f'[trace] SclEventManager.processEvent() ENTER')

        derivedConclusionEvents = []

        for iEventWatchdog in self.eventWatchdogs:
            if iEventWatchdog.detectorType.typeName == event.payload.type_.typeName: # does type of event match the type of the event for which the detector is looking for?
                thisDerivedConclusionEvents = iEventWatchdog.trigger(event) # then trigger the watchdog!
                derivedConclusionEvents += thisDerivedConclusionEvents
        
        print(f'[trace] SclEventManager.processEvent() EXIT')

        return derivedConclusionEvents
'''









# * holds rules
# * returns rules which match a given "Type"
class SclRuleManager(object):
    def __init__(self):
        # set of all rules in the system
        self.ruleSet = []
    
    # method to apply possible rules to a given datum
    def applyForwardAll(self, input_):
        ensureType(input_, TypedInst)

        applicableRules = self.retForwardRulesOfType(input_.type_.typeName) # filter for applicable rules which have the given input type
        
        res = []
        for iRule in applicableRules:
            thisRes = iRule.applyForward(input_)
            res.append(thisRes)
        
        return res
    
    # method to apply possible rules to a given datum
    def applyBackwardAll(self, output_):
        ensureType(output_, TypedInst)

        applicableRules = self.retBackwardRulesOfType(output_.type_.typeName) # filter for applicable rules which have the given input type
        
        res = []
        for iRule in applicableRules:
            thisRes = iRule.applyBackward(output_)
            res.append({'derivedGoal':thisRes, 'rule':iRule})
        
        return res

    # helper
    def retForwardRulesOfType(self, typeName):
        ensureType(typeName, str)

        res = []
        for iRule in self.ruleSet:
            if iRule.inputType.typeName == typeName:
                res.append(iRule)
        return res
    
    # helper
    def retBackwardRulesOfType(self, typeName):
        ensureType(typeName, str)

        res = []
        for iRule in self.ruleSet:
            if iRule.outputType.typeName == typeName:
                res.append(iRule)
        return res
    
























# function of RULE which is used to plan backward from a goal which is expressed as a goal-type to a sub-goal which is expressed as a goal-type
class PlanningTestARuleFunction(object):
    def __init__(self):
        pass
    
    def applyForward(self, forwardInput):
        ensureType(forwardInput, TypedInst)

        # NOTE  we do forward planning - which is the execution of the implemented functionality

        print('[trace] PlanningTestARuleFunction.applyForward() called')

        #  return a actual "TypedInst"
        outputTypedInst = TypedInst(Type('goalA'))
        return outputTypedInst
    
    def applyBackward(self, backwardOutput):
        ensureType(backwardOutput, TypedInst)

        if not (backwardOutput.type_.typeName == 'goalA'):
            raise InterpretationSoftError('must be of type goalA')

        # backward planning from "backwardOutput" to backward-input

        backwardInput = TypedInst(Type('clockTickA'))

        backwardInput.dat = None # TODO  :  put something into the "backwardInput" datum as payload

        return backwardInput









# function of RULE which is used to generate a random result, this is used to test this architecture if it could handle tools which are unreliable
class ReliabilityTestBRuleFunction(object):
    def __init__(self):
        pass
    
    def applyForward(self, forwardInput):
        ensureType(forwardInput, TypedInst)

        # NOTE  we do forward planning - which is the execution of the implemented functionality

        print('[trace] ReliabilityTestBRuleFunction.applyForward() called')

        #  return a actual "TypedInst"
        outputTypedInst = TypedInst(Type('failableA'))
        outputTypedInst.dat = random.randint(0, 2) == 0
        return outputTypedInst
    
    def applyBackward(self, backwardOutput):
        ensureType(backwardOutput, TypedInst)

        if not (backwardOutput.type_.typeName == 'failableA'):
            raise InterpretationSoftError('must be of type failableA')

        # backward planning from "backwardOutput" to backward-input

        backwardInput = TypedInst(Type('a0'))
        backwardInput.dat = None # has no payload for backward planning
        return backwardInput

# function of RULE which is used to consume SclEvent:failableA and decide how to proceed based on payload. forwardOutput is of type SclEvent:rootGoal
class FailableConsumerTestBRuleFunction(object):
    def __init__(self):
        pass
    
    def applyForward(self, forwardInput):
        ensureType(forwardInput, TypedInst)

        # NOTE  we do forward planning - which is the execution of the implemented functionality

        print('[trace] FailableConsumerTestBRuleFunction.applyForward() called')

        print(f'[info ] payload={forwardInput.dat}')

        failableSucceeded = forwardInput.dat
        if not failableSucceeded:
            print('[info ] failable failed!')

            # TODO LOW  :  implement soft-error handling here

        #  return a actual "TypedInst"
        outputTypedInst = TypedInst(Type('rootGoal'))
        outputTypedInst.dat = None # no payload
        return outputTypedInst
    
    def applyBackward(self, backwardOutput):
        ensureType(backwardOutput, TypedInst)

        if not (backwardOutput.type_.typeName == 'rootGoal'):
            raise InterpretationSoftError('must be of type rootGoal')

        # backward planning from "backwardOutput" to backward-input

        backwardInput = TypedInst(Type('failableA'))
        backwardInput.dat = None # has no payload for backward planning
        return backwardInput











# function
class AppRunOnlineLearningHopfieldLmToProcessTextRuleFunction(object):
    def __init__(self):
        pass
    
    def applyForward(self, forwardInput):
        ensureType(forwardInput, TypedInst)

        # NOTE  we do forward planning - which is the execution of the implemented functionality

        print('[trace] AppRunOnlineLearningHopfieldLmToProcessTextRuleFunction.applyForward() called')







        #print(f'[info ] payload={forwardInput.dat}')

        # question: 'What is Bifidobacterium bifidum?'
        #prompt0 = 'Bifidobacterium bifidum is'
        prompt0 = forwardInput.dat['answerBeginningHumanTxt']
        prompt0 = 'Y~'*(2**9) + prompt0 # hacky way to fill tokens

        # idea: use online learning hopfield LM to search for text
        # 
        if True: # codeblock

            from entryModernHopfieldLmA import OnlineLearningHopfieldLm
            
            lm = OnlineLearningHopfieldLm()


            # * now we need to tokenize the text of the training-set in the path with the temporary text files

            from transformers import GPT2Tokenizer, GPT2Model
            tokenizer = GPT2Tokenizer.from_pretrained('gpt2')

            txtAll = '~'*500
            


            directoryWithTrainingDataPath = "C:\\Users\\rober\\fsRoot\\MYdata\\used_for_apsiringprotoagi"

            import os
            for iFilename in os.listdir(directoryWithTrainingDataPath):
                if os.path.isfile(os.path.join(directoryWithTrainingDataPath, iFilename)): # Check if it's a file (not a directory) using os.path.isfile
                    fullPath = os.path.join(directoryWithTrainingDataPath, iFilename)
                    print(f'[trace ] reading file for training data:   path={fullPath}')

                    def readTextfileUtf8(filepath):
                        try:
                            with open(filepath, 'r', encoding='utf-8') as f:
                                content = f.read()
                                return content
                        except FileNotFoundError:
                            #print(f"Error: File not found: {filepath}")
                            return None
                        except Exception as e:
                            #print(f"Error reading file: {filepath} - {e}")
                            return None
                    
                    txtAll += readTextfileUtf8(fullPath)



            
            inputs = tokenizer(txtAll, return_tensors="pt")

            trainingsetTokens = inputs['input_ids'].detach().numpy()[0].tolist()

            # * we also need to train the LM

            lm.train(trainingsetTokens)

            # * now we use the LM to complete the question which we pose as an answer




            import lmLibB

            args = {}
            args['completionCount'] = 70
            response0Txt = lmLibB.lmInferenceByText(lm, tokenizer, prompt0, args)

            print(f'[dbg  ] responseTxtFromLm={response0Txt}')

            # * now we return the answer

            #  return a actual "TypedInst"
            outputTypedInst = TypedInst(Type('processTextWithLm'))
            outputTypedInst.dat = response0Txt # payload is the actual text of the response
            return outputTypedInst






    
    def applyBackward(self, backwardOutput):
        ensureType(backwardOutput, TypedInst)

        if not (backwardOutput.type_.typeName == 'processTextWithLm'):
            raise InterpretationSoftError('must be of type processTextWithLm')

        # backward planning from "backwardOutput" to backward-input

        backwardInput = TypedInst(Type('a1'))
        backwardInput.dat = None # has no payload for backward planning
        return backwardInput



# function
#
# fetches text from a source (in our case the internet)
class AppRunFetchTextRuleFunction(object):
    def __init__(self):
        pass
    
    def applyForward(self, forwardInput):
        ensureType(forwardInput, TypedInst)

        # NOTE  we do forward planning - which is the execution of the implemented functionality

        print('[trace] AppRunFetchTextRuleFunction.applyForward() called')


        # TODO TODO TODO TODO

        # * now we return the answer

        #  return a actual "TypedInst"
        outputTypedInst = TypedInst(Type('a1'))
        outputTypedInst.dat = {'answerBeginningHumanTxt': forwardInput.dat['answerBeginningHumanTxt']} # data passthrough
        return outputTypedInst
    
    def applyBackward(self, backwardOutput):
        ensureType(backwardOutput, TypedInst)

        if not (backwardOutput.type_.typeName == 'a1'):
            raise InterpretationSoftError('must be of type a1')

        # backward planning from "backwardOutput" to backward-input

        backwardInput = TypedInst(Type('a2'))
        backwardInput.dat = None # has no payload for backward planning
        return backwardInput










class GlobalCtx(object):
    def __init__(self):
        self.scheduler = SclScheduler()
        self.ruleManager = SclRuleManager()
        #self.eventManager = SclEventManager()


        # set of 'SclEventDetector's for which the system is looking for.
        # 
        # 
        # # commented because not integrated/used yet
        maxCapacityEventDetectors = 1000
        self.eventDetectors = ResourceBoundedTable(maxCapacityEventDetectors)


'''
# /param e "SclEvent" to check
def processEvent_TODOINTEGRATEME(globalCtx, e):
    for iEventDetector in globalCtx.eventDetectors:
        if iEventDetector.checkPatternMatch(e): # check if event matches to pattern of the actual detector
            # now we call the actual detector to process the event
            iEventDetector(e)
'''
















# MANUAL TEST for application of rule
if __name__ == "__main__":

    # what is the name of the program entry we want to run?
    # REFACTOR LOW  :  this should be a python program parameter
    entryName = 'appUseLm'







    # create global context
    globalCtx = GlobalCtx()


















    '''commented because not used
    # install SclEventWatchdog to process SclEvent:autofire
    createdEventWatchdog = SclEventWatchdog(Type('autofire'), SclEventWatchdogForAutofire(globalCtx))
    globalCtx.eventManager.eventWatchdogs.append(createdEventWatchdog) # register watchdog
    '''






    # * we start the system
    # ** for that we have to set the time to the current time
    globalCtx.scheduler.systemStartAbsoluteTime = time.time()



    if entryName == 'testing':

        # rule for sub-goaling of a goal of type 'goalA' to type 'autofire'
        createdRule = SclRule(
            Type('clockTickA'), # input type
            Type('goalA'), # output type
            PlanningTestARuleFunction() # function which will be used for forward/backward planning
        )
        globalCtx.ruleManager.ruleSet.append(createdRule)

        # rule for generating failable result
        createdRule = SclRule(
            Type('a0'), # input type
            Type('failableA'), # output type
            ReliabilityTestBRuleFunction()
        )
        globalCtx.ruleManager.ruleSet.append(createdRule)

        # rule for processing failable result
        createdRule = SclRule(
            Type('failableA'),
            Type('rootGoal'),
            FailableConsumerTestBRuleFunction()
        )
        globalCtx.ruleManager.ruleSet.append(createdRule)



        if True: # codeblock
            # create actual goal to be processed and put it into a task which will get scheduled by the scheduler

            goalA = TypedInst(Type('goalA'))
            goalA.dat = None # it currently doesnt have any data
            
            createdPendingTask = {}
            createdPendingTask['activeFrom'] = 0.0 # set absolute time when the job will be added as active job
            createdPendingTask['kind'] = 'goal' # job is to process a goal with backward-inference
            createdPendingTask['val'] = goalA # actual job is to process the goal with backward inference
            globalCtx.scheduler.pendingInactiveTasks.append(createdPendingTask)


        

        while True:
            # HACKY  :  exit the whole system after it did run for a given time amount
            if globalCtx.scheduler.cachedSystemClockTime > 0.2:
                break
            
            schedulerTick(globalCtx.scheduler, globalCtx)
        


        # now we add a event for testing if forward inference for an event works fine
        eventA = SclEvent(TypedInst(Type('clockTickA')))
        createdPendingJob = {}
        createdPendingJob['activeFrom'] = 0.0 # set absolute time when the job will be added as active job
        createdPendingJob['kind'] = 'event' # job is to process a event with forward-inference
        createdPendingJob['val'] = eventA # actual job is to process the event with forward inference
        globalCtx.scheduler.putJob(createdPendingJob)


        # put for testing event SclEvent:a0 into the system to test generation of unreliable result as event SclEvent:failableA
        eventA = SclEvent(TypedInst(Type('a0')))
        createdPendingJob = {}
        createdPendingJob['activeFrom'] = 0.0 # set absolute time when the job will be added as active job
        createdPendingJob['kind'] = 'event' # job is to process a event with forward-inference
        createdPendingJob['val'] = eventA # actual job is to process the event with forward inference
        globalCtx.scheduler.putJob(createdPendingJob)


        while True:
            # HACKY  :  exit the whole system after it did run for a given time amount
            if globalCtx.scheduler.cachedSystemClockTime > 0.4:
                break
            
            schedulerTick(globalCtx.scheduler, globalCtx)

    # application which uses LM    
    elif entryName == 'appUseLm':

        

        # (Application)
        # rule for rnning a hopfield LM with text from files
        createdRule = SclRule(
            Type('a1'), # input type
            Type('processTextWithLm'), # output type
            AppRunOnlineLearningHopfieldLmToProcessTextRuleFunction()
        )
        globalCtx.ruleManager.ruleSet.append(createdRule)


        createdRule = SclRule(
            Type('a2'), # input type
            Type('a1'), # output type
            AppRunFetchTextRuleFunction()
        )
        globalCtx.ruleManager.ruleSet.append(createdRule)




        goalA = TypedInst(Type('processTextWithLm'))
        goalA.dat = None  # it currently doesnt have any data

        createdPendingTask = {}
        createdPendingTask['activeFrom'] = 0.0  # set absolute time when the job will be added as active job
        createdPendingTask['kind'] = 'goal'  # job is to process a goal with backward-inference
        createdPendingTask['val'] = goalA  # actual job is to process the goal with backward inference
        globalCtx.scheduler.pendingInactiveTasks.append(createdPendingTask)

        while True:
            # HACKY
            if globalCtx.scheduler.cachedSystemClockTime > 0.5:
                break

            schedulerTick(globalCtx.scheduler, globalCtx)



        # put for running the LM the event SclEvent:a1 into the system
        typedInst = TypedInst(Type('a2'))
        typedInst.dat = {'answerBeginningHumanTxt':'Bifidobacterium bifidum is'} # data to pass around with the "TypedInst"
        eventA = SclEvent(typedInst)
        createdPendingJob = {}
        createdPendingJob['activeFrom'] = 0.0 # set absolute time when the job will be added as active job
        createdPendingJob['kind'] = 'event' # job is to process a event with forward-inference
        createdPendingJob['val'] = eventA # actual job is to process the event with forward inference
        globalCtx.scheduler.putJob(createdPendingJob)








        while True:
            # HACKY  :  exit the whole system after it did run for a given time amount
            if globalCtx.scheduler.cachedSystemClockTime > 4.0:
                break
            
            schedulerTick(globalCtx.scheduler, globalCtx)



    print(f'[info] FIN')
    
    # exit(0)



# DONE :  add test SCL-Function which returns a type where the payload says that it has been processed successfully or that a recoverableFailure occurred
#    DONE  :  add SCL-Function with input SclType:a0 and output SclType:failableA . The function returns as payload a boolean which is true or false depending on RNG
#    DONE  :  add SCL-function with input SclType:failableA and output SclType:rootGoal  . The function only prints if the payload is true or false, and does have code to print a dummy message when it is false (this is the case when a failable operation failed)






# DONE

# DONE refactor  :  add 'event' job type : which indicates a pending event which needs to get processed

# DONE?  :  implement multistep planning and execution
#      DONE  :  implement triggering of event when forward was done! (because the forward inference produced TypedInst as a output which needs to get processed at some point







# HALFDONE  :  implement some triggering mechanism with a hashtable by type of the event where forward inference is only done if it occurs in the table
#    TODO  :  the table has to be maintained under AIKR!
#        TODO  :  call into maintaining of table every X seconds




# IDEAS

# IDEA  :  add event type 'clockTickA' which happens every 0.1 seconds to process stuff which needs to get processed regularly


# chaos place for ideas:
# 
# "timelyUtility" : how to compute the 'utility' of a job which is bound by a soft deadline
#      idea here: utility decreases linearly after soft deadline has passed
# 
# 
# 
# def calcTimelyUtility(currentTime, startTime, beginSoftDeadline, falloffFactor):
#    timelyUtility = 1.0 - (currentTime - startTime) # utility decreases with passage of time
#    
#    if currentTime < beginSoftDeadline:
#       timelyUtility # is not punished because soft dealine is not reached
#    
#    return timelyUtility - (currentTime - beginSoftDealine)*falloffFactor # else we punish it more and more 














''' commented because not used

# reward a job for completion or failure
# /param reward 1 or -1
def rewardJob(jobDat, reward):
    jobDat['rewardInt'] += reward
'''




################## STAGING AREA (things to add soon)



